# frozen_string_literal: true

module ToMods
  # Writes MODS XML name elements from cocina contributor
  class NameWriter # rubocop:disable Metrics/ClassLength
    # cocina contributor type => MODS name type
    # one way mapping:  MODS 'corporate' already maps to Cocina 'organization'
    NAME_TYPE = {
      'person' => 'personal',
      'organization' => 'corporate',
      'family' => 'family',
      'conference' => 'conference'
    }.freeze
    # cocina name part type => MODS namePart type
    NAME_PART = {
      'surname' => 'family',
      'forename' => 'given',
      'term of address' => 'termsOfAddress',
      'life dates' => 'date',
      'activity dates' => 'date'
    }.freeze

    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] contributor a cocina contributor
    # @params [IdGenerator] id_generator
    # @params [Hash<Hash, Hash<Hash, Integer>>] name_title_vals_index is a Hash
    #   the key is a hash representing a single contributor name, with a key of 'value' or 'structuredValue'
    #   the value is a hash, where
    #      the key is a hash representing a single title value, with a key of 'value' or 'structuredValue'
    #      the value is the nameTitleGroup number as an Integer
    #   e.g. {{"value"=>"James Joyce"}=>{"value"=>"Portrait of the artist as a young man"}=>1}
    def self.write(xml:, contributor:, id_generator:, name_title_vals_index: {})
      new(xml: xml, contributor: contributor, id_generator: id_generator,
          name_title_vals_index: name_title_vals_index).write
    end

    def initialize(xml:, contributor:, id_generator:, name_title_vals_index: {})
      @xml = xml
      @contributor = CocinaDisplay::Contributors::Contributor.new(contributor)
      @id_generator = id_generator
      @name_title_vals_index = name_title_vals_index
    end

    def write
      if unspecified_others?
        write_etal
      elsif contributor.names.present?
        # Expect contributor to have a single value for name property
        contrib_name = first_name
        parallel_name_values = Query.parallel_values(contrib_name)
        if parallel_name_values.present?
          write_contributor_with_parallel_names(parallel_name_values, contrib_name)
        else
          write_contributor(contributor)
        end
      end
    end

    private

    # @return [CocinaDisplay::Contributors::Contributor]
    attr_reader :contributor
    attr_reader :xml, :name_title_vals_index, :id_generator

    # @return [Hash] the cocina of the contributor's first name
    def first_name
      contributor.names.first.cocina
    end

    def unspecified_others?
      contributor_type == 'unspecified others'
    end

    def contributor_type
      Query.type(contributor.cocina)
    end

    def write_etal
      xml.name do
        xml.etal
      end
    end

    def write_contributor(contributor)
      name_title_group = nil

      contrib_name_value_slices = NameTitleGroup.contributor_name_value_slices(contributor.cocina)
      contrib_name_value_slices.each do |contrib_name_value_slice|
        next if name_title_vals_index.blank?

        name_title_group = name_title_vals_index[contrib_name_value_slice]&.values&.first
      end

      attributes = name_attributes(contributor, first_name, name_title_group)
      type_attr = NAME_TYPE.fetch(Query.type(contributor.cocina), name_title_group ? 'personal' : nil)
      attributes[:type] = type_attr if type_attr
      xml.name attributes do
        contributor.names.each do |name|
          write_name(name.cocina)
        end
        write_identifier(contributor) if contributor.identifiers.present?
        write_affiliation(contributor)
        write_note(contributor)
        write_roles(contributor)
        xml.etal if unspecified_others?
      end
    end

    def write_name(name)
      if Query.structured?(name)
        write_structured(name)
      elsif Query.grouped?(name)
        write_grouped(name)
      elsif Query.value(name)
        Query.type(name) == 'display' ? write_display_form(name) : write_basic(name)
      end
    end

    def write_contributor_with_parallel_names(parallel_name_values, contrib_name)
      display_type_parallel_name = display_type_parallel_name(parallel_name_values)
      if parallel_name_values.size == 1
        contrib_name_value_slice = NameTitleGroup.value_slices(parallel_name_values.first)
        name_title_group = name_title_vals_index[contrib_name_value_slice]&.values&.first
        write_name_from_parallel(contributor, first_name, parallel_name_values.first, name_title_group, nil)
      elsif parallel_name_values.size == 2 && display_type_parallel_name
        contrib_name_value_slice = NameTitleGroup.value_slices(parallel_name_values.first)
        name_title_group = name_title_vals_index[contrib_name_value_slice]&.values&.first
        write_name_with_display_form(contributor, first_name, parallel_name_values, 0, name_title_group, nil)
      else
        write_multiple_parallel_contributors(parallel_name_values, contrib_name)
      end
    end

    def write_multiple_parallel_contributors(parallel_name_values, contrib_name)
      altrepgroup_id = id_generator.next_altrepgroup
      parallel_name_values.each_with_index do |parallel_contrib_name, index|
        display_name_present = parallel_name_values[index + 1].present? && Query.type(parallel_name_values[index + 1]) == 'display'
        NameTitleGroup.value_slices(parallel_contrib_name).each do |parallel_contrib_name_slice|
          if name_title_vals_index[parallel_contrib_name_slice]
            name_title_group = name_title_vals_index[parallel_contrib_name_slice]&.values&.first
            if display_name_present
              # associate type 'display' with the previous value
              write_name_with_display_form(contributor, contrib_name, parallel_name_values, index, name_title_group, altrepgroup_id)
            else
              write_name_from_parallel(contributor, contrib_name, parallel_contrib_name, name_title_group, altrepgroup_id)
            end
          elsif display_name_present
            # TODO:  want a way to notify that we hit a problem - either notifier or HB error (issue #3751)
            #  OR validate for semantic correctness upon creation/update so we can't get here.
            #  notifier.warn("For contributor name '#{parallel_contrib_name_slice}', no contrib matching")
            write_name_with_display_form(contributor, contrib_name, parallel_name_values, index, nil, altrepgroup_id)
          elsif Query.type(parallel_name_values[index]) == 'display'
            # we assume we included this as part of a previous name
            next
          else
            write_name_from_parallel(contributor, contrib_name, parallel_contrib_name, nil, altrepgroup_id)
          end
        end
      end
    end

    def write_name_from_parallel(contributor, name, parallel_name, name_title_group, altrepgroup_id)
      attributes = parallel_name_attributes(name, parallel_name, name_title_group, altrepgroup_id)
      type_attr = NAME_TYPE.fetch(Query.type(contributor.cocina), name_title_group ? 'personal' : nil)
      attributes[:type] = type_attr if type_attr
      xml.name attributes do
        if Query.structured?(parallel_name)
          write_structured(parallel_name)
        else
          write_basic(parallel_name)
        end
        write_identifier(contributor) if contributor.identifiers.present?
        write_affiliation(contributor)
        write_note(contributor)
        write_roles(contributor)
      end
    end

    # rubocop:disable Metrics/ParameterLists
    def write_name_with_display_form(contributor, name, parallel_name_values, index, name_title_group, altrepgroup_id)
      display_type_parallel_name = display_type_parallel_name(parallel_name_values)
      parallel_name = parallel_name_values[index]
      return if parallel_name.blank?

      attributes = if altrepgroup_id.present?
                     parallel_name_attributes(name, parallel_name, name_title_group, altrepgroup_id)
                   else
                     name_attributes(contributor, name, nil)
                   end
      type_attr = NAME_TYPE.fetch(Query.type(contributor.cocina), name_title_group ? 'personal' : nil)
      attributes[:type] = type_attr if type_attr
      xml.name attributes do
        if Query.structured?(parallel_name)
          write_structured(parallel_name)
        else
          write_basic(parallel_name)
        end
        write_display_form(display_type_parallel_name) if display_type_parallel_name.present?
        write_identifier(contributor) if contributor.identifiers.present?
        write_affiliation(contributor)
        write_note(contributor)
        write_roles(contributor)
      end
    end
    # rubocop:enable Metrics/ParameterLists

    def display_type_parallel_name(parallel_name_values)
      parallel_name_values.detect { |parallel_value| Query.type(parallel_value) == 'display' }
    end

    def parallel_name_attributes(name, parallel_name, name_title_group, altrepgroup_id)
      {
        nameTitleGroup: name_title_group,
        altRepGroup: altrepgroup_id,
        lang: Query.lang(parallel_name),
        script: Query.script(parallel_name),
        authority: Query.authority(parallel_name),
        valueURI: Query.uri(parallel_name),
        authorityURI: Query.authority_uri(parallel_name)
      }.tap do |attributes|
        attributes[:usage] = 'primary' if Query.status(parallel_name) == 'primary'
        attributes[:transliteration] = Query.standard_value(parallel_name) if Query.type(parallel_name) == 'transliteration'
        attributes['xlink:href'] = Query.value_at(name)
      end.compact
    end

    def name_attributes(contributor, name, name_title_group)
      {
        nameTitleGroup: name_title_group,
        lang: Query.lang(name),
        script: Query.script(name),
        valueURI: Query.uri(name),
        authority: Query.authority(name),
        authorityURI: Query.authority_uri(name),
        displayLabel: Query.display_label(name)
      }.tap do |attributes|
        attributes[:usage] = 'primary' if contributor.primary?
        attributes['xlink:href'] = Query.value_at(name)
      end.compact
    end

    def write_roles(contributor)
      contributor.roles.each do |role|
        RoleWriter.write(xml: xml, role: role.cocina)
      end
    end

    def write_basic(name)
      xml.namePart Query.value(name), name_part_attributes(name)
    end

    def name_part_attributes(part)
      {
        type: NAME_PART[Query.type(part)]
      }.tap do |attributes|
        attributes['xlink:href'] = Query.value_at(part)
      end.compact
    end

    def write_structured(name)
      Query.structured_values(name).each do |part|
        xml.namePart Query.value(part), name_part_attributes(part)
      end
    end

    def write_grouped(name)
      Query.grouped_values(name).each do |part|
        case Query.type(part)
        when 'pseudonym'
          xml.alternativeName Query.value(part), name_part_attributes(part).merge({ altType: 'pseudonym' })
        when 'alternative'
          xml.alternativeName Query.value(part), name_part_attributes(part)
        else
          write_name(part)
        end
      end
    end

    def write_affiliation(contributor)
      contributor.affiliations.each do |affiliation|
        xml.affiliation affiliation.display_name
      end
    end

    def write_note(contributor)
      Query.notes(contributor.cocina).each do |note|
        case Query.type(note)
        when 'affiliation'
          xml.affiliation Query.value(note)
        when 'description'
          xml.description Query.value(note)
        end
      end
    end

    def write_identifier(contributor)
      # CocinaDisplay::Identifier#value and #type normalize the cocina, so the raw values are used here.
      contributor.identifiers.map(&:cocina).each do |identifier|
        id_attributes = {
          displayLabel: Query.display_label(identifier),
          typeURI: Query.authority_uri(identifier),
          type: IdentifierType.mods_type_for_cocina_type(Query.type(identifier))
        }.tap do |attrs|
          attrs[:invalid] = 'yes' if Query.status(identifier) == 'invalid'
        end.compact
        xml.nameIdentifier Query.value(identifier) || Query.uri(identifier), id_attributes
      end
    end

    def write_display_form(name)
      xml.displayForm Query.value(name) if Query.type(name) == 'display'
    end
  end
end
