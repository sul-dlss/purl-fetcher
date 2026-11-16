# frozen_string_literal: true

module ToMods
  # Helpers for MODS nameTitleGroups.
  #   MODS titles need to know if they match a contributor and thus need a nameTitleGroup
  #   MODS contributors need to know if they match a title and thus need a nameTitleGroup
  #     If there is a match, the nameTitleGroup number has to be consistent for the matching title(s)
  #     and the contributor(s)
  #
  # When to assign nameTitleGroup to MODS from cocina:
  #   for cocina title of type "uniform",
  #     look for cocina title properties value or structuredValue (recurse down through parallelValue
  #     as needed), and look for associated note with type of "associated name" at the level of the
  #     non-empty title [value|structuredValue]
  #     The note of type "associated name" will have [value|structuredValue] which will match
  #     [value|structuredValue] for a contributor (possibly after recursing through parallelValue).
  #   Thus, a title [value|structuredValue] and a contributor [value|structuredValue] are associated in
  #   cocina.
  #
  # If those criteria not met in Cocina, do not assign nameTitleGroup in MODS
  #
  # All "slices" returned by these methods are normalized (blank values removed at every level) so
  # that a title's associated name and a contributor's name compare as equal even if one of them
  # carries empty properties (e.g. "note": []) that the other omits.
  #
  # NOTE: CocinaDisplay has no notion of nameTitleGroups. Matching a title to a contributor means
  # comparing their cocina structures for equality, so this works directly on the cocina hashes.
  #
  # Originally derived from Cocina::Models::Builders::NameTitleGroupBuilder
  class NameTitleGroup
    # @params [Hash] contributor
    # @params [Array<Hash>] titles
    # @return [boolean] true if contributor part of name title group
    def self.in_name_title_group?(contributor:, titles:)
      return false if contributor.blank? || titles.blank? || !Query.present?(contributor, '$.name[*]')

      contrib_name_value_slices = contributor_name_value_slices(contributor)
      Array(titles).each do |title|
        build_title_values_to_contributor_name_values(title).each_value do |name|
          return true if contrib_name_value_slices.include?(name)
        end
      end

      false
    end

    # @params [Hash] title
    # @return [Hash<Hash, Hash>] key:  hash of value or structuredValue property for title
    #   value: hash of value or structuredValue property for contributor
    #   e.g. {{"value"=>"Portrait of the artist as a young man"}=>{"value"=>"James Joyce"}}
    #   e.g. {{"value"=>"Portrait of the artist as a young man"}=>{"structuredValue"=>
    #         [{"value"=>"Joyce, James", "type"=>"name"},{"value"=>"1882-1941", "type"=>"life dates"}]}}
    #   e.g. {{"structuredValue"=>[{"value"=>"Demanding Food", "type"=>"main"},
    #           {"value"=>"A Cat's Life", "type"=>"subtitle"}]}=>{"value"=>"James Joyce"}}
    #   this complexity is needed for multilingual titles mapping to multilingual names.
    def self.build_title_values_to_contributor_name_values(title)
      result = {}
      return result if title.blank?

      # pair title value with contributor name value
      title_value_note_slices(title).each do |value_note_slice|
        title_val_slice = slice_of_value_or_structured_value(value_note_slice)
        next if title_val_slice.blank?

        associated_name_note = Query.notes_of_type(value_note_slice, 'associated name').first
        next if associated_name_note.blank?

        # relevant note will be either
        #   { "value" => 'string contributor name', "type" => 'associated name' }
        # OR
        #   { "structuredValue" => [ structuredValue contributor name ], "type" => 'associated name' }
        # and we want the hash without the type attribute
        result[title_val_slice] = slice_of_value_or_structured_value(associated_name_note)
      end
      result
    end

    # @params [Hash] contributor
    # @return [Array<Hash>, nil] where we are only interested in
    #   hashes containing (either value or structuredValue)
    def self.contributor_name_value_slices(contributor)
      names = Query.search(contributor, '$.name[*]')
      return if names.blank?

      names.flat_map { |contrib_name| value_slices(contrib_name) }
    end

    # @params [Hash] desc_value
    # @return [Array<Hash>] where we are only interested in
    #   hashes containing (either value or structuredValue)
    def self.value_slices(desc_value)
      desc_value_slice = normalize(desc_value.slice('value', 'structuredValue', 'parallelValue'))
      if desc_value_slice['value'].present? || desc_value_slice['structuredValue'].present?
        [desc_value_slice]
      else
        # ignoring groupedValue
        Array(desc_value_slice['parallelValue']).flat_map { |parallel_val| value_slices(parallel_val) }
      end
    end

    # for a given Hash (from a Cocina DescriptiveValue or Title or Name or ...)
    # result will be either
    #   { "value" => 'string value' }
    # OR
    #   { "structuredValue" => [ some structuredValue ] }
    # @return [Hash, nil]
    def self.slice_of_value_or_structured_value(hash)
      if hash['value'].present?
        normalize(hash.slice('value'))
      elsif hash['structuredValue'].present?
        normalize(hash.slice('structuredValue'))
      end
    end

    # reduce parallelValues down to value or structuredValue for these slices
    # @params [Hash] title
    # @return [Array<Hash>] where we are only interested in
    #   hashes containing (either value or structuredValue) and note if present
    def self.title_value_note_slices(title)
      title_slice = normalize(title.slice('value', 'structuredValue', 'parallelValue', 'note'))
      if title_slice['value'].present? || title_slice['structuredValue'].present?
        [title_slice]
      else
        # ignoring groupedValue
        Array(title_slice['parallelValue']).flat_map { |parallel_val| title_value_note_slices(parallel_val) }
      end
    end

    # Recursively remove blank values so that equivalent cocina compares as equal.
    def self.normalize(value)
      case value
      when Hash
        value.transform_values { |v| normalize(v) }.compact_blank
      when Array
        value.map { |v| normalize(v) }.compact_blank
      else
        value
      end
    end
  end
end
