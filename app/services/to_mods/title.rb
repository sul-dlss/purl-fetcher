# frozen_string_literal: true

module ToMods
  # Maps titles from cocina to MODS XML
  #   NOTE: contributors from nameTitleGroups are output here as well;
  #   this allows for consistency of the nameTitleGroup number for the matching title(s) and the contributor(s)
  class Title # rubocop:disable Metrics/ClassLength
    # cocina title part type => MODS titleInfo child element
    TAG_NAME = {
      'nonsorting characters' => 'nonSort',
      'main title' => 'title',
      'subtitle' => 'subTitle',
      'part number' => 'partNumber',
      'part name' => 'partName',
      'life dates' => 'date',
      'activity dates' => 'date',
      'forename' => 'given',
      'surname' => 'family',
      'title' => 'uniform'
    }.freeze
    NAME_TYPES = ['name', 'forename', 'surname', 'life dates', 'term of address'].freeze

    def self.write(...)
      new(...).write
    end

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] titles
    # @params [IdGenerator] id_generator
    # @params [Array<Hash>] contributors
    # @params [Hash] additional_attrs for title
    # @params [Array<Hash>] catalog_links a list of catalog
    #   links which may contain part label and sort key information
    def initialize(xml:, titles:, id_generator:, contributors: [], additional_attrs: {}, catalog_links: []) # rubocop:disable Metrics/ParameterLists
      @xml = xml
      @titles = Array(titles)
      @id_generator = id_generator
      @contributors = Array(contributors)
      @additional_attrs = additional_attrs
      @catalog_links = Array(catalog_links)
      @name_title_vals_index = {}
    end

    def write # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      titles.each do |title| # rubocop:disable Metrics/BlockLength
        name_title_vals_index = name_title_vals_index_for(title)

        if title['valueAt']
          write_xlink(title: title)
        elsif title['parallelValue'].present?
          write_parallel(title: title, title_info_attrs: additional_attrs)
        elsif title['groupedValue'].present?
          write_grouped(title: title, title_info_attrs: additional_attrs)
        elsif title['structuredValue'].present?
          if name_title_vals_index.present?
            title_value_slice = NameTitleGroup.slice_of_value_or_structured_value(title)
            # don't leak nameTitleGroup into later titles
            my_additional_attrs = additional_attrs.dup
            my_additional_attrs[:nameTitleGroup] = name_title_group_number(title_value_slice)
            write_structured(title: title, title_info_attrs: my_additional_attrs.compact)
          else
            write_structured(title: title, title_info_attrs: additional_attrs.compact)
          end
        elsif title['value']
          if name_title_vals_index.present?
            title_value_slice = NameTitleGroup.slice_of_value_or_structured_value(title)
            # don't leak nameTitleGroup into later titles
            my_additional_attrs = additional_attrs.dup
            my_additional_attrs[:nameTitleGroup] = name_title_group_number(title_value_slice)
            write_basic(title: title, title_info_attrs: my_additional_attrs.compact)
          else
            write_basic(title: title, title_info_attrs: additional_attrs.compact)
          end
        end

        associated_name = NameTitleGroup.title_value_note_slices(title).each do |value_note_slice|
          Array(value_note_slice['note']).detect { |note| note['type'] == 'associated name' }
        end
        next if associated_name.blank?

        contributors.each do |contributor|
          if NameTitleGroup.in_name_title_group?(contributor: contributor, titles: [title])
            NameWriter.write(xml: xml, contributor: contributor,
                             name_title_vals_index: name_title_vals_index, id_generator: id_generator)
          end
        end
      end
    end

    private

    attr_reader :xml, :titles, :contributors, :name_title_vals_index, :id_generator, :additional_attrs, :catalog_links

    def write_xlink(title:)
      attrs = { 'xlink:href' => title['valueAt'] }
      xml.titleInfo attrs
    end

    def write_basic(title:, title_info_attrs: {})
      title_info_attrs = title_info_attrs_for(title).merge(title_info_attrs)

      xml.titleInfo(title_info_attrs) do
        xml.title(title['value'])
        if title['status'] == 'primary' &&
           (part_label = folio_part_label)
          xml.partNumber(part_label)
        end
      end
    end

    # rubocop:disable Metrics/AbcSize
    def write_parallel(title:, title_info_attrs: {})
      title_alt_rep_group = id_generator.next_altrepgroup

      title['parallelValue'].each do |parallel_title|
        parallel_attrs = title_info_attrs.dup
        parallel_attrs[:altRepGroup] = title_alt_rep_group
        parallel_attrs[:lang] = parallel_title.dig('valueLanguage', 'code') if parallel_title.dig('valueLanguage', 'code')
        if title['type'] == 'uniform'
          parallel_attrs[:type] = 'uniform'
          if name_title_vals_index.present?
            title_value_slice = NameTitleGroup.slice_of_value_or_structured_value(parallel_title)
            parallel_attrs[:nameTitleGroup] = name_title_group_number(title_value_slice)
          end
        elsif parallel_title['type'] == 'transliterated'
          parallel_attrs[:type] = 'translated'
          parallel_attrs[:transliteration] = parallel_title.dig('standard', 'value')
        elsif title['parallelValue'].any? { |parallel_value| parallel_value['status'] == 'primary' }
          if parallel_title['status'] == 'primary'
            parallel_attrs[:usage] = 'primary'
          elsif parallel_title['type'] == 'translated'
            parallel_attrs[:type] = 'translated'
          end
        end

        if parallel_title['structuredValue'].present?
          write_structured(title: parallel_title, title_info_attrs: parallel_attrs.compact)
        elsif parallel_title['value']
          write_basic(title: parallel_title, title_info_attrs: parallel_attrs.compact)
        end
      end
    end

    # rubocop:enable Metrics/AbcSize
    def write_grouped(title:, title_info_attrs: {})
      title['groupedValue'].each do |grouped_title|
        write_basic(title: grouped_title, title_info_attrs: title_info_attrs)
      end
    end

    # @params [Hash] title
    # @return [Hash<Hash, Hash<Hash, Integer>>]
    #   the key is a hash representing a single contributor name, with a key of 'value' or 'structuredValue'
    #   the value is a hash, where
    #      the key is a hash representing a single title value, with a key of 'value' or 'structuredValue'
    #      the value is the nameTitleGroup number as an Integer
    #   e.g. {{:value=>"James Joyce"}=>{:value=>"Portrait of the artist as a young man"}=>1,
    #   e.g.  {:value=>"Vinsky Cat"}=>{:structuredValue=>[{:value=>"Demanding Food", :type=>"main"},{:value=>"A Cat's Life", :type=>"subtitle"}]}=>2}
    #
    # This complexity is needed for multilingual titles mapping to multilingual names. :-P
    def name_title_vals_index_for(title)
      return nil unless contributors

      title_vals_to_contrib_name_vals = NameTitleGroup.build_title_values_to_contributor_name_values(title)
      return nil if title_vals_to_contrib_name_vals.blank?

      title_value_slices = NameTitleGroup.value_slices(title)
      title_value_slices.each do |title_value_slice|
        contrib_name_val_slice = title_vals_to_contrib_name_vals[title_value_slice]
        next if contrib_name_val_slice.blank?

        name_title_group = id_generator.next_nametitlegroup
        name_title_vals_index[contrib_name_val_slice] = { title_value_slice => name_title_group }
      end

      name_title_vals_index
    end

    def write_structured(title:, title_info_attrs: {})
      title_info_attrs = title_info_attrs_for(title).merge(title_info_attrs)
      xml.titleInfo(with_uri_info(title, title_info_attrs)) do
        title_parts = flatten_structured_value(title)
        write_title_parts!(title_parts: title_parts_without_names(title_parts), title: title)
      end
    end

    def write_title_parts!(title_parts:, title:)
      # If title parts contain the main title and a part label has been
      # recorded in a catalog link, short-circuit the usual title part
      # parsing and pull the part label from the catalog link instead of
      # from descriptive metadata
      if (main_title = title_parts.find { |part| part['type'] == 'main title' }&.dig('value')) &&
         (part_label = folio_part_label)
        xml.title(main_title)
        xml.partNumber(part_label)
      else
        title_parts.each do |title_part|
          title_type = tag_name_for(title_part)
          raise "Unknown title type for: #{title_part}" unless title_type

          title_value = title_value_for(title_part, title_type, title)
          xml.public_send(title_type, title_value) if title_part['note'].blank?
        end
      end
    end

    def title_value_for(title_part, title_type, title)
      return title_part['value'] unless title_type == 'nonSort'

      non_sorting_size = [non_sorting_char_count_for(title) - (title_part['value']&.size || 0), 0].max
      "#{title_part['value']}#{' ' * non_sorting_size}"
    end

    def non_sorting_char_count_for(title)
      non_sort_note = Array(title['note']).find { |note| note['type']&.downcase == 'nonsorting character count' }
      return 0 unless non_sort_note

      non_sort_note['value'].to_i
    end

    # Flatten the structuredValues into a simple list.
    def flatten_structured_value(title)
      leafs = Array(title['structuredValue']).select { |value| value['value'] }
      nodes = Array(title['structuredValue']).select { |value| value['structuredValue'].present? }.reject { |value| value['type'] == 'name' }
      leafs + nodes.flat_map { |node| flatten_structured_value(node) }
    end

    # Filter out name types
    def title_parts_without_names(parts)
      parts.reject { |structured_title| NAME_TYPES.include?(structured_title['type']) }
    end

    def with_uri_info(cocina, xml_attrs)
      xml_attrs[:valueURI] = cocina['uri']
      xml_attrs[:authorityURI] = cocina.dig('source', 'uri')
      xml_attrs[:authority] = cocina.dig('source', 'code')
      xml_attrs.compact
    end

    def tag_name_for(title_part)
      return 'title' if title_part['type'] == 'title'

      TAG_NAME.fetch(title_part['type'], nil)
    end

    def title_info_attrs_for(title)
      {
        usage: title['status'],
        script: title.dig('valueLanguage', 'valueScript', 'code'),
        lang: title.dig('valueLanguage', 'code'),
        displayLabel: title['displayLabel'],
        valueURI: title['uri'],
        authorityURI: title.dig('source', 'uri'),
        authority: title.dig('source', 'code'),
        transliteration: title.dig('standard', 'value')
      }.tap do |attrs|
        if title['type'] == 'supplied'
          attrs[:supplied] = 'yes'
        elsif title['type'] != 'transliterated'
          attrs[:type] = title['type']
        end
      end.compact
    end

    # @return [Integer] the integer to be used for a nameTitleGroup attribute
    def name_title_group_number(title_value_slice)
      # name_title_vals_index is [Hash<Hash, Hash<Hash, Integer>>]
      #   the key is a hash representing a single contributor name, with a key of 'value' or 'structuredValue'
      #   the value is a hash, where
      #      the key is a hash representing a single title value, with a key of 'value' or 'structuredValue'
      #      the value is the nameTitleGroup number as an Integer
      #   e.g. {{"value"=>"James Joyce"}=>{"value"=>"Portrait of the artist as a young man"}=>1}
      #
      # This complexity is needed for multilingual titles mapping to multilingual names. :-P
      name_title_vals_index.values.detect { |hash| hash.key?(title_value_slice) }&.values&.first
    end

    # @return [String, nil] a part label recorded in a folio catalog link
    def folio_part_label
      catalog_links.find { |link| link['catalog'] == 'folio' && link['partLabel'].present? }&.dig('partLabel')
    end
  end
end
