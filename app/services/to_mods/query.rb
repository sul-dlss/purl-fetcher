# frozen_string_literal: true

module ToMods
  # JSONPath accessors for the cocina properties that MODS needs but CocinaDisplay doesn't expose.
  #
  # CocinaDisplay is built for display, so it offers formatted strings rather than the raw
  # attributes (uri, authority, displayLabel, etc.) that become MODS attributes. Rather than walking
  # hashes ad hoc in every writer, all such reads go through these named queries so that a change to
  # the cocina schema only needs to be accommodated here.
  #
  # Queries are parsed once and cached.
  # @see app/services/to_mods/README.md
  module Query
    # @param node [Hash, Array, nil] a cocina node
    # @param jsonpath [String]
    # @return [Array] all values matching the query
    def self.search(node, jsonpath)
      return [] if node.blank?

      compiled(jsonpath).enum_for(node).search
    end

    # @param node [Hash, Array, nil] a cocina node
    # @param jsonpath [String]
    # @return [Object, nil] the first value matching the query
    def self.first(node, jsonpath)
      search(node, jsonpath).first
    end

    # @param node [Hash, Array, nil] a cocina node
    # @param jsonpath [String]
    # @return [Boolean] true if the query matches a non-blank value
    def self.present?(node, jsonpath)
      search(node, jsonpath).any?(&:present?)
    end

    def self.compiled(jsonpath)
      CACHE.compute_if_absent(jsonpath) { Janeway.parse(jsonpath) }
    end

    # Quote a string for use as a literal in a JSONPath filter expression.
    def self.literal(str)
      "'#{str.to_s.gsub('\\', '\\\\\\\\').gsub("'", "\\\\'")}'"
    end

    CACHE = Concurrent::Map.new

    # Simple properties of a DescriptiveValue (or similar) node
    def self.value(node) = first(node, '$.value')
    def self.code(node) = first(node, '$.code')
    def self.uri(node) = first(node, '$.uri')
    def self.type(node) = first(node, '$.type')
    def self.status(node) = first(node, '$.status')
    def self.display_label(node) = first(node, '$.displayLabel')
    def self.value_at(node) = first(node, '$.valueAt')
    def self.qualifier(node) = first(node, '$.qualifier')

    # The source (authority) of a node
    def self.source(node) = first(node, '$.source')
    def self.authority(node) = first(node, '$.source.code')
    def self.authority_uri(node) = first(node, '$.source.uri')
    def self.source_value(node) = first(node, '$.source.value')
    def self.source_version(node) = first(node, '$.source.version')

    def self.encoding(node) = first(node, '$.encoding')
    def self.encoding_code(node) = first(node, '$.encoding.code')
    def self.standard(node) = first(node, '$.standard')
    def self.standard_value(node) = first(node, '$.standard.value')
    def self.standard_code(node) = first(node, '$.standard.code')

    # Nested values
    def self.structured_values(node) = search(node, '$.structuredValue[*]')
    def self.grouped_values(node) = search(node, '$.groupedValue[*]')
    def self.parallel_values(node) = search(node, '$.parallelValue[*]')
    def self.structured?(node) = present?(node, '$.structuredValue[*]')
    def self.grouped?(node) = present?(node, '$.groupedValue[*]')
    def self.parallel?(node) = present?(node, '$.parallelValue[*]')

    # Notes and other repeated properties
    def self.notes(node) = search(node, '$.note[*]')
    def self.identifiers(node) = search(node, '$.identifier[*]')
    def self.applies_to_values(node) = search(node, '$.appliesTo[*].value')

    # @return [Array<Hash>] the notes with the given type
    def self.notes_of_type(node, type)
      search(node, "$.note[?@.type == #{literal(type)}]")
    end

    # @return [String, nil] the value of the first note with the given type
    def self.note_value_of_type(node, type)
      first(node, "$.note[?@.type == #{literal(type)}].value")
    end

    # @return [Hash, nil] the first member of the array with the given type
    def self.first_of_type(nodes, type)
      first(Array(nodes), "$[?@.type == #{literal(type)}]")
    end

    # @return [String, nil] the value of the first member of the array with the given type
    def self.value_of_type(nodes, type)
      first(Array(nodes), "$[?@.type == #{literal(type)}].value")
    end

    # The language of a node, using CocinaDisplay so that both valueScript and script are understood.
    # @return [CocinaDisplay::Languages::Language, nil]
    def self.language(node)
      value_language = first(node, '$.valueLanguage')
      CocinaDisplay::Languages::Language.new(value_language) if value_language.present?
    end

    # @return [String, nil] the language code of a node
    def self.lang(node) = language(node)&.code

    # @return [String, nil] the script code of a node
    def self.script(node) = language(node)&.script&.code
  end
end
