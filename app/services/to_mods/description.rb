# frozen_string_literal: true

require 'nokogiri'

module ToMods
  # This transforms the DRO.description schema to MODS xml
  class Description
    MODS_VERSION_REGEX = /MODS version (\d\.\d)/
    DEFAULT_MODS_VERSION = '3.7'

    # @param [Hash] description the cocina description (string or symbol keys)
    # @param [string] druid
    # @param [Hash] identification the cocina identification (string or symbol keys)
    # @return [Nokogiri::XML::Document]
    def self.transform(description, druid, identification: nil)
      new(description, druid, identification).transform
    end

    def initialize(description, druid, identification)
      @druid = druid
      @record = CocinaDisplay::CocinaRecord.new(
        {
          'externalIdentifier' => druid,
          'description' => description.to_h.deep_stringify_keys,
          'identification' => identification&.to_h&.deep_stringify_keys
        }.compact
      )
    end

    # @return [Nokogiri::XML::Document]
    def transform
      Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.mods(mods_attributes) do
          ModsWriter.write(xml: xml, record: record, druid: druid)
        end
      end.doc
    end

    private

    attr_reader :record, :druid

    def mods_version
      @mods_version ||= record.path("$.description.adminMetadata.note[?@.type == 'record origin'].value")
                              .search
                              .filter_map { |value| MODS_VERSION_REGEX.match(value)&.[](1) }
                              .first || DEFAULT_MODS_VERSION
    end

    def mods_attributes
      {
        'xmlns' => 'http://www.loc.gov/mods/v3',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xmlns:rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        'xmlns:xlink' => 'http://www.w3.org/1999/xlink',
        'version' => mods_version,
        'xsi:schemaLocation' => "http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-#{mods_version.sub(
          '.', '-'
        )}.xsd"
      }
    end
  end
end
