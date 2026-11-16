# frozen_string_literal: true

module ToMods
  # Maps description resource from cocina to MODS XML
  class ModsWriter
    # @params [Nokogiri::XML::Builder] xml
    # @param [Hash] description a cocina description or relatedResource (string keys)
    # @param [string] druid
    # @param [Hash] identification a cocina identification (string keys)
    def self.write(xml:, description:, druid:, id_generator: IdGenerator.new, identification: nil)
      # ID Generator makes sure that different writers create unique altRepGroups and nameTitleGroups.
      titles = Array(description['title'])
      contributors = Array(description['contributor'])
      if titles.present?
        catalog_links = Array(identification&.dig('catalogLinks')).select { |link| link['catalog'] == 'folio' }
        Title.write(xml: xml, titles: titles, contributors: contributors,
                    id_generator: id_generator, catalog_links: catalog_links)
      end
      Contributor.write(xml: xml, contributors: contributors, titles: titles,
                        id_generator: id_generator)
      Form.write(xml: xml, forms: description['form'], id_generator: id_generator)
      Language.write(xml: xml, languages: description['language'])
      Note.write(xml: xml, notes: description['note'], id_generator: id_generator)
      Subject.write(xml: xml, subjects: description['subject'], forms: description['form'],
                    id_generator: id_generator)
      Event.write(xml: xml, events: description['event'], id_generator: id_generator)
      Identifier.write(xml: xml, identifiers: description['identifier'], id_generator: id_generator)
      Access.write(xml: xml, access: description['access'], purl: description['purl'])
      AdminMetadata.write(xml: xml, admin_metadata: description['adminMetadata'])
      RelatedResource.write(xml: xml, related_resources: description['relatedResource'], druid: druid,
                            id_generator: id_generator)
      Geographic.write(xml: xml, geos: description['geographic'], druid: druid)
    end
  end
end
