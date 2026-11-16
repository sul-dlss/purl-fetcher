# frozen_string_literal: true

module ToMods
  # Maps geo extension from cocina to MODS
  #
  # NOTE: CocinaDisplay's geospatial support (Geospatial::Coordinates, CocinaRecord#coordinates) parses
  # coordinates into normalized points and envelopes for display and indexing. The MODS geo extension
  # needs the coordinate values exactly as recorded, so JSONPath queries are used instead.
  class Geographic
    ABOUT_URI_PREFIX = 'http://purl.stanford.edu/'

    MEDIA_TYPE = "$.form[?@.type == 'media type' && @.value != 'Image']"
    DATA_FORMAT = "$.form[?@.type == 'data format']"
    RESOURCE_TYPE = "$.form[?@.type == 'type' || (@.type == 'media type' && @.value == 'Image')]"
    FIRST_SUBJECT = '$.subject[0]'
    COVERAGE = "$.subject[?search(@.type, 'coverage')]"

    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] geos
    def self.write(xml:, geos:, druid:)
      new(xml: xml, geos: geos, druid: druid).write
    end

    def initialize(xml:, geos:, druid:)
      @xml = xml
      @geos = geos
      @druid = druid
    end

    def write
      return if geos.blank?

      geos.map do |geo|
        attributes = {}
        attributes[:displayLabel] = 'geo'
        xml.extension attributes do
          xml['rdf'].RDF(format_namespace(geo)) do
            xml['rdf'].Description('rdf:about' => about(druid)) do
              add_format(extract_format(geo))
              add_type(Query.first(geo, "#{RESOURCE_TYPE}.value"))
              add_content(geo)
            end
          end
        end
      end
    end

    private

    attr_reader :xml, :geos, :druid

    def format_namespace(geo)
      namespace = {
        'xmlns:gml' => 'http://www.opengis.net/gml/3.2/',
        'xmlns:dc' => 'http://purl.org/dc/elements/1.1/'
      }

      namespace['xmlns:gmd'] = 'http://www.isotc211.org/2005/gmd' if first_subject_type(geo)&.include? 'point coordinates'

      namespace
    end

    def extract_format(geo)
      media_type = Query.first(geo, "#{MEDIA_TYPE}.value")
      data_format = Query.first(geo, "#{DATA_FORMAT}.value")

      return "#{media_type}; format=#{data_format}" if data_format && media_type

      media_type
    end

    def about(druid)
      "#{ABOUT_URI_PREFIX}#{druid.delete_prefix('druid:')}"
    end

    def add_format(data)
      xml['dc'].format data if data
    end

    def add_type(type)
      xml['dc'].type type if type
    end

    def add_content(geo)
      case first_subject_type(geo)
      when 'point coordinates'
        add_centerpoint(geo)
      when 'bounding box coordinates'
        add_bounding_box(geo)
        add_coverage(geo)
      end
    end

    def add_centerpoint(geo)
      lat = Query.first(geo, "#{FIRST_SUBJECT}.structuredValue[?search(@.type, 'latitude')].value")
      long = Query.first(geo, "#{FIRST_SUBJECT}.structuredValue[?search(@.type, 'longitude')].value")
      xml['gmd'].centerPoint do
        xml['gml'].Point do
          xml['gml'].pos "#{lat} #{long}"
        end
      end
    end

    def add_bounding_box(geo)
      srs_name = Query.first(geo, "#{FIRST_SUBJECT}.standard.code")
      standard_tag = srs_name ? { 'gml:srsName' => srs_name } : {}
      xml['gml'].boundedBy do
        xml['gml'].Envelope(standard_tag) do
          coords = bounding_box_coordinates_for(geo)
          xml['gml'].lowerCorner "#{coords['west']} #{coords['south']}"
          xml['gml'].upperCorner "#{coords['east']} #{coords['north']}"
        end
      end
    end

    # @return [Hash<String, String>] coordinate values keyed by direction (west, south, east, north)
    def bounding_box_coordinates_for(geo)
      Query.search(geo, "#{FIRST_SUBJECT}.structuredValue[*]").to_h { |direction| [Query.type(direction), Query.value(direction)] }
    end

    def add_coverage(geo)
      Query.search(geo, COVERAGE).each do |data|
        coverage_attributes = {
          'rdf:resource' => Query.uri(data),
          'dc:language' => Query.lang(data),
          'dc:title' => Query.value(data)
        }.compact
        xml['dc'].coverage coverage_attributes
      end
    end

    def first_subject_type(geo)
      Query.first(geo, "#{FIRST_SUBJECT}.type")
    end
  end
end
