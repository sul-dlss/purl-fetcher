# frozen_string_literal: true

module ToMods
  # Maps parts from cocina to MODS XML
  #
  # NOTE: CocinaDisplay only exposes part notes as flattened values (NoteValue#values_by_type),
  # which loses the grouping into MODS detail and extent elements, so JSONPath queries are used.
  class PartWriter
    DETAIL_TYPES = %w[number caption title].freeze
    OTHER_TYPES = %w[text date].freeze

    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] part_note
    def self.write(xml:, part_note:)
      new(xml: xml, part_note: part_note).write
    end

    def initialize(xml:, part_note:)
      @xml = xml
      @note = part_note
    end

    def write
      if Query.grouped?(note)
        write_grouped_value
      else
        write_structured_value
      end
    end

    private

    attr_reader :xml, :note

    def write_grouped_value
      xml.part do
        write_detail(note)
        other_note_values_for(note).each { |other_value| write_part_note_value(other_value) }
        write_extent_for(note)
      end
    end

    def write_structured_value
      xml.part do
        Query.structured_values(note).each do |note_value|
          write_detail(note_value)
          write_part_note_value(note_value) if other_note?(note_value)
          write_extent_for(note_value)
        end
      end
    end

    def write_detail(note_value)
      grouped_values = Query.grouped_values(note_value)
      detail_values = grouped_values.select { |value| DETAIL_TYPES.include?(Query.type(value)) }
      return if detail_values.blank?

      attrs = { type: Query.value_of_type(grouped_values, 'detail type') }.compact
      xml.detail attrs do
        detail_values.each { |detail_value| write_part_note_value(detail_value) }
      end
    end

    def write_extent_for(note_value)
      grouped_values = Query.grouped_values(note_value)
      list_value = Query.value_of_type(grouped_values, 'list')
      structured_values = Query.structured_values(grouped_values.find { |value| Query.structured?(value) })
      start_value = Query.value_of_type(structured_values, 'start')
      end_value = Query.value_of_type(structured_values, 'end')
      return unless list_value || start_value || end_value

      extent_attrs = { unit: Query.value_of_type(grouped_values, 'extent unit') }.compact

      xml.extent extent_attrs do
        xml.list list_value if list_value
        xml.start start_value if start_value
        xml.end end_value if end_value
      end
    end

    def other_note_values_for(note_value)
      Query.grouped_values(note_value).select { |value| other_note?(value) }
    end

    def other_note?(value)
      OTHER_TYPES.include?(Query.type(value))
    end

    def write_part_note_value(value)
      # One of the tag names is "text". Since this is also a method name, normal magic doesn't work.
      xml.method_missing Query.type(value), Query.value(value)
    end
  end
end
