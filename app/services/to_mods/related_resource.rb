# frozen_string_literal: true

module ToMods
  # Maps relatedResource from cocina to MODS relatedItem
  class RelatedResource
    # see https://docs.google.com/spreadsheets/d/1d5PokzgXqNykvQeckG2ND43B6i9_CsjfIVwS_IsphS8/edit#gid=0
    # TODO: Replace with FromMods::RelatedResource::TYPES.invert
    TYPES = {
      'has original version' => 'original',
      'has other format' => 'otherFormat',
      'has part' => 'constituent',
      'has version' => 'otherVersion',
      'in series' => 'series',
      'part of' => 'host',
      'preceded by' => 'preceding',
      'related to' => nil, # 'related to' is a null type by design
      'reviewed by' => 'reviewOf',
      'referenced by' => 'isReferencedBy',
      'references' => 'references',
      'succeeded by' => 'succeeding'
    }.freeze

    OTHER_TYPES = [
      'supplement to',
      'supplemented by',
      'derived from',
      'source of',
      'version of record',
      'identical to'
    ].freeze

    # TODO: Replace with FromMods::RelatedResource::DETAIL_TYPES.invert
    DETAIL_TYPES = {
      'location within source' => 'part',
      'volume' => 'volume',
      'issue' => 'issue',
      'chapter' => 'chapter',
      'section' => 'section',
      'paragraph' => 'paragraph',
      'track' => 'track',
      'marker' => 'marker'
    }.freeze

    OTHER_TYPE_NOTE = "$.note[?@.type == 'other relation type']"
    NOTES_EXCEPT_OTHER_TYPE = "$.note[?@.type != 'other relation type']"

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] related_resources
    # @param [string] druid
    # @param [IdGenerator] id_generator
    def self.write(xml:, related_resources:, druid:, id_generator:)
      new(xml: xml, related_resources: related_resources, druid: druid, id_generator: id_generator).write
    end

    def initialize(xml:, related_resources:, druid:, id_generator:)
      @xml = xml
      @related_resources = Array(related_resources)
      @druid = druid
      @id_generator = id_generator
    end

    def write
      related_resources.each do |related|
        if (value_at = Query.value_at(related))
          deferred_links << value_at
          next
        end

        xml.relatedItem attributes_for(related) do
          ModsWriter.write(xml: xml, record: related_record_for(related), druid: druid, id_generator: id_generator)
        end
      end

      deferred_links.each do |value_at|
        xml.relatedItem nil, { 'xlink:href' => value_at }
      end
    end

    private

    attr_reader :xml, :related_resources, :druid, :id_generator

    # relatedItems that only link to another record are written after the others
    def deferred_links
      @deferred_links ||= []
    end

    # The related resource, without the note that is mapped to relatedItem attributes,
    # as a CocinaDisplay record that can be written like a description.
    # @return [CocinaDisplay::RelatedResource]
    def related_record_for(related)
      CocinaDisplay::RelatedResource.new(related.merge('note' => Query.search(related, NOTES_EXCEPT_OTHER_TYPE)))
    end

    def attributes_for(related)
      other_type_note = Query.first(related, OTHER_TYPE_NOTE)
      type = Query.type(related)
      {}.tap do |attrs|
        if type
          if (mapped_type = TYPES[type])
            attrs[:type] = mapped_type
          elsif OTHER_TYPES.include?(type)
            attrs[:otherType] = type
          end
        end
        attrs[:displayLabel] = Query.display_label(related)

        if other_type_note
          attrs[:otherType] = Query.value(other_type_note)
          attrs[:otherTypeURI] = Query.uri(other_type_note)
          attrs[:otherTypeAuth] = Query.source_value(other_type_note)
        end
      end.compact
    end
  end
end
