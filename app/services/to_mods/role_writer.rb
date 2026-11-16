# frozen_string_literal: true

module ToMods
  # Maps roles from cocina to MODS XML
  class RoleWriter
    SELF_DEPOSIT_CONTRIBUTOR_TYPES = 'Stanford self-deposit contributor types'

    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] role a cocina DescriptiveValue
    def self.write(xml:, role:)
      new(xml: xml, role: role).write
    end

    def initialize(xml:, role:)
      @xml = xml
      @role = CocinaDisplay::Contributors::Role.new(role)
    end

    def write
      xml.role do
        attributes = {
          valueURI: Query.uri(role.cocina),
          authority: Query.authority(role.cocina),
          authorityURI: Query.authority_uri(role.cocina)
        }.compact
        # Role#to_s would fall back to a label decoded from the MARC relator code, but MODS only
        # records the text value when it is present in the cocina.
        value = Query.value(role.cocina)
        if value.present?
          attributes[:type] = 'text'
          value = value.downcase if Query.source_value(role.cocina) == SELF_DEPOSIT_CONTRIBUTOR_TYPES
          xml.roleTerm value, attributes
        end
        if role.code.present?
          attributes[:type] = 'code'
          xml.roleTerm role.code, attributes
        end
      end
    end

    private

    attr_reader :xml, :role
  end
end
