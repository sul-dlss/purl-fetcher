# frozen_string_literal: true

module ToMods
  # Maps adminMetadata from cocina to MODS XML recordInfo
  #
  # NOTE: CocinaDisplay only exposes the admin creation event (CocinaRecord#admin_creation_event),
  # and its dates are filtered to those it can parse, so JSONPath queries are used here.
  class AdminMetadata
    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] admin_metadata
    def self.write(xml:, admin_metadata:)
      new(xml: xml, admin_metadata: admin_metadata).write
    end

    def initialize(xml:, admin_metadata:)
      @xml = xml
      @admin_metadata = admin_metadata
    end

    def write
      return unless admin_metadata

      xml.recordInfo do
        build_language
        build_content_source
        build_description_standard
        build_record_origin
        build_record_info_notes
        build_event
        build_identifier
      end
    end

    private

    attr_reader :xml, :admin_metadata

    def build_record_origin
      Query.notes_of_type(admin_metadata, 'record origin').each do |note|
        xml.recordOrigin Query.value(note)
      end
    end

    def build_record_info_notes
      Query.notes(admin_metadata).each do |info_note|
        if (value_at = Query.value_at(info_note)).present?
          xml.recordInfoNote nil, { 'xlink:href' => value_at }
        elsif Query.type(info_note) == 'record information'
          xml.recordInfoNote Query.value(info_note)
        end
      end
    end

    def build_content_source
      Query.search(admin_metadata, '$.contributor[*]').each do |contributor|
        source = Query.first(contributor, '$.name[0]')
        xml.recordContentSource Query.code(source) || Query.value(source), with_uri_info(source)
      end
    end

    def build_description_standard
      Query.search(admin_metadata, '$.metadataStandard[*]').each do |standard|
        xml.descriptionStandard Query.code(standard) || Query.value(standard), with_uri_info(standard)
      end
    end

    def build_event
      build_event_for('creation', 'recordCreationDate')
      build_event_for('modification', 'recordChangeDate')
    end

    def build_event_for(type, tag)
      Query.search(admin_metadata, "$.event[?@.type == #{Query.literal(type)}].date[*]").each do |date|
        attributes = { encoding: Query.encoding_code(date) }.compact
        xml.public_send(tag, Query.value(date), attributes)
      end
    end

    def build_identifier
      Query.identifiers(admin_metadata).each do |identifier|
        uri = Query.uri(identifier)
        id_attributes = {
          displayLabel: Query.display_label(identifier),
          source: uri ? 'uri' : IdentifierType.mods_type_for_cocina_type(Query.type(identifier))
        }.tap do |attrs|
          attrs[:invalid] = 'yes' if Query.status(identifier) == 'invalid'
        end.compact
        xml.recordIdentifier Query.value(identifier) || uri, id_attributes
      end
    end

    def build_language
      Query.search(admin_metadata, '$.language[*]').each do |language_cocina|
        language = CocinaDisplay::Languages::Language.new(language_cocina)
        language_of_cataloging_attrs = { usage: Query.status(language_cocina) }.compact
        xml.languageOfCataloging language_of_cataloging_attrs do
          language_attrs = with_uri_info(language_cocina)
          value = Query.value(language_cocina)
          xml.languageTerm value, language_attrs.merge(type: 'text') if value
          xml.languageTerm language.code, language_attrs.merge(type: 'code') if language.code
          if (script = language.script)
            script_attrs = with_uri_info(script.cocina)
            xml.scriptTerm Query.value(script.cocina), script_attrs.merge(type: 'text')
            xml.scriptTerm script.code, script_attrs.merge(type: 'code')
          end
        end
      end
    end

    def with_uri_info(cocina)
      {
        valueURI: Query.uri(cocina),
        authorityURI: Query.authority_uri(cocina),
        authority: Query.authority(cocina)
      }.compact
    end
  end
end
