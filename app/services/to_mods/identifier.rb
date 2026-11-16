# frozen_string_literal: true

module ToMods
  # Maps identifiers from cocina to MODS XML
  #
  # NOTE: CocinaDisplay::Identifier is not used: its #value prefers the uri over the value and its
  # #type normalizes DOI/ORCID types, whereas MODS needs the cocina value and type as recorded.
  class Identifier
    # @params [Nokogiri::XML::Builder] xml
    # @params [Array<Hash>] identifiers
    # @params [IdGenerator] id_generator
    def self.write(xml:, identifiers:, id_generator:)
      new(xml: xml, identifiers: identifiers, id_generator: id_generator).write
    end

    def initialize(xml:, identifiers:, id_generator:)
      @xml = xml
      @identifiers = identifiers
      @id_generator = id_generator
    end

    def write
      Array(identifiers).each do |identifier|
        if Query.parallel?(identifier)
          write_parallel(identifier)
        else
          write_identifier(identifier)
        end
      end
    end

    private

    attr_reader :xml, :identifiers, :id_generator

    def write_parallel(parallel_identifier)
      altrepgroup_id = id_generator.next_altrepgroup
      Query.parallel_values(parallel_identifier).each do |identifier|
        write_identifier(identifier, altrepgroup_id: altrepgroup_id)
      end
    end

    def write_identifier(identifier, altrepgroup_id: nil)
      uri = Query.uri(identifier)
      id_attributes = {
        displayLabel: Query.display_label(identifier),
        type: uri ? 'uri' : IdentifierType.mods_type_for_cocina_type(Query.type(identifier)),
        altRepGroup: altrepgroup_id
      }.tap do |attrs|
        attrs[:invalid] = 'yes' if Query.status(identifier) == 'invalid'
      end.compact
      xml.identifier Query.value(identifier) || uri, id_attributes
    end
  end
end
