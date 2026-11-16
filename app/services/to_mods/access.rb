# frozen_string_literal: true

module ToMods
  # Maps the Access subschema from cocina to MODS XML
  class Access
    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] access a cocina DescriptiveAccessMetadata
    # @params [string] purl
    def self.write(xml:, access:, purl:)
      new(xml: xml, access: access, purl: purl).write
    end

    def initialize(xml:, access:, purl:)
      @xml = xml
      @access = access
      @purl = purl
    end

    def write
      write_purl unless purl.nil?
      return if access.nil?

      write_access_conditions

      urls.each do |url|
        xml.location do
          write_url(url)
        end
      end

      write_physical_locations
      write_digital_locations
      write_shelf_locators
      write_access_contact_locations
    end

    private

    attr_reader :xml, :access, :purl

    def urls
      Query.search(access, '$.url[*]').map { |url| CocinaDisplay::Description::Url.new(url) }
    end

    def physical_locations
      Query.search(access, '$.physicalLocation[*]').map { |location| CocinaDisplay::Description::Access.new(location) }
    end

    def access_notes
      Query.notes(access)
    end

    def write_physical_locations
      physical_locations.reject { |physical_location| shelf_locator?(physical_location) }.each do |physical_location|
        xml.location do
          xml.physicalLocation value_or_code(physical_location.cocina), descriptive_attrs(physical_location.cocina)
        end
      end
    end

    def write_digital_locations
      Query.search(access, "$.digitalLocation[?@.type == 'discovery']").each do |digital_location|
        xml.location do
          xml.physicalLocation value_or_code(digital_location), descriptive_attrs(digital_location)
        end
      end
    end

    def write_access_contact_locations
      Query.search(access, '$.accessContact[*]').each do |cocina|
        access_contact = CocinaDisplay::Description::AccessContact.new(cocina)
        if access_contact.contact_email?
          xml.note Query.value(cocina), descriptive_attrs(cocina).merge({ type: 'contact' })
        else
          xml.location do
            xml.physicalLocation value_or_code(cocina), { type: 'repository' }.merge(descriptive_attrs(cocina))
          end
        end
      end
    end

    def write_shelf_locators
      physical_locations.select { |physical_location| shelf_locator?(physical_location) }.each do |physical_location|
        xml.location do
          xml.shelfLocator Query.value(physical_location.cocina)
        end
      end
    end

    # @param [CocinaDisplay::Description::Url] url
    def write_url(url)
      url_attrs = {}.tap do |attrs|
        attrs[:usage] = 'primary display' if primary?(url.cocina)
        attrs[:displayLabel] = url.link_text
        attrs[:note] = Query.first(url.cocina, '$.note[0].value') if Query.notes(url.cocina).present?
      end.compact
      xml.url Query.value(url.cocina), url_attrs
    end

    def primary_url_is_not_purl?
      urls.any? { |url| primary?(url.cocina) }
    end

    def primary?(cocina)
      Query.status(cocina) == 'primary'
    end

    def write_purl
      purl_attrs = {}.tap do |attrs|
        attrs[:note] = purl_note_value(nil)
        attrs[:usage] = 'primary display' unless primary_url_is_not_purl?
        attrs[:displayLabel] = purl_note_value('display label')
      end.compact

      xml.location do
        xml.url purl, purl_attrs
      end
    end

    def purl_note_value(note_type)
      access_notes.find do |note|
        Query.type(note) == note_type && purl_note?(note)
      end&.then { |note| Query.value(note) }
    end

    def value_or_code(cocina)
      Query.value(cocina) || Query.code(cocina)
    end

    def descriptive_attrs(cocina)
      {
        valueURI: Query.uri(cocina),
        authorityURI: Query.authority_uri(cocina),
        authority: Query.authority(cocina),
        script: Query.script(cocina),
        lang: Query.lang(cocina),
        type: Query.type(cocina),
        displayLabel: Query.display_label(cocina),
        'xlink:href' => Query.value_at(cocina)
      }.compact
    end

    # @param [CocinaDisplay::Description::Access] physical_location
    def shelf_locator?(physical_location)
      physical_location.type == 'shelf locator'
    end

    def write_access_conditions
      access_notes.reject { |note| purl_note?(note) }.each do |note|
        type = Query.type(note)
        attributes = {
          type: type == 'access restriction' ? 'restriction on access' : type,
          displayLabel: Query.display_label(note),
          'xlink:href' => Query.value_at(note)
        }.compact
        xml.accessCondition Query.value(note), attributes
      end
    end

    def purl_note?(note)
      Query.applies_to_values(note).include?('purl')
    end
  end
end
