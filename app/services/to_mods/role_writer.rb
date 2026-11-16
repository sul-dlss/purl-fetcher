# frozen_string_literal: true

module ToMods
  # Maps roles from cocina to MODS XML
  class RoleWriter
    # @params [Nokogiri::XML::Builder] xml
    # @params [Hash] role a cocina DescriptiveValue
    def self.write(xml:, role:)
      new(xml: xml, role: role).write
    end

    def initialize(xml:, role:)
      @xml = xml
      @role = role
    end

    def write
      xml.role do
        attributes = {
          valueURI: role['uri'],
          authority: role.dig('source', 'code'),
          authorityURI: role.dig('source', 'uri')
        }.compact
        if role['value'].present?
          attributes[:type] = 'text'
          value = if role.dig('source', 'value') == 'Stanford self-deposit contributor types'
                    role['value'].downcase
                  else
                    role['value']
                  end
          xml.roleTerm value, attributes
        end
        if role['code'].present?
          attributes[:type] = 'code'
          xml.roleTerm role['code'], attributes
        end
      end
    end

    private

    attr_reader :xml, :role
  end
end
