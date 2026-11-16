# frozen_string_literal: true

module ToMods
  # Maps description resource from cocina to MODS XML
  class ModsWriter
    # @params [Nokogiri::XML::Builder] xml
    # @param [CocinaDisplay::JsonBackedRecord] record a CocinaDisplay::CocinaRecord, or a
    #   CocinaDisplay::RelatedResource for a nested relatedItem
    # @param [string] druid
    # @param [IdGenerator] id_generator makes sure that different writers create unique altRepGroups and nameTitleGroups.
    def self.write(xml:, record:, druid:, id_generator: IdGenerator.new)
      new(xml: xml, record: record, druid: druid, id_generator: id_generator).write
    end

    def initialize(xml:, record:, druid:, id_generator:)
      @xml = xml
      @record = record
      @druid = druid
      @id_generator = id_generator
    end

    def write
      if titles.present?
        Title.write(xml: xml, titles: titles, contributors: contributors,
                    id_generator: id_generator, catalog_links: folio_catalog_links)
      end
      Contributor.write(xml: xml, contributors: contributors, titles: titles, id_generator: id_generator)
      Form.write(xml: xml, forms: forms, id_generator: id_generator)
      Language.write(xml: xml, languages: description('language[*]'))
      Note.write(xml: xml, notes: description('note[*]'), id_generator: id_generator)
      Subject.write(xml: xml, subjects: description('subject[*]'), forms: forms, id_generator: id_generator)
      Event.write(xml: xml, events: description('event[*]'), id_generator: id_generator)
      Identifier.write(xml: xml, identifiers: description('identifier[*]'), id_generator: id_generator)
      Access.write(xml: xml, access: description('access').first, purl: description('purl').first)
      AdminMetadata.write(xml: xml, admin_metadata: description('adminMetadata').first)
      RelatedResource.write(xml: xml, related_resources: description('relatedResource[*]'), druid: druid,
                            id_generator: id_generator)
      Geographic.write(xml: xml, geos: description('geographic[*]'), druid: druid)
    end

    private

    attr_reader :xml, :record, :druid, :id_generator

    # NOTE: CocinaRecord#contributors, #all_forms and #all_subjects are not used: they also include
    # event contributors and geographic forms and subjects, which map to other MODS elements.
    # The writers receive the cocina hashes and wrap them in CocinaDisplay objects as needed.
    # @return [Array<Hash>] the matching cocina nodes in the description
    def description(jsonpath)
      record.path("$.description.#{jsonpath}").search
    end

    def titles
      @titles ||= description('title[*]')
    end

    def contributors
      @contributors ||= description('contributor[*]')
    end

    def forms
      @forms ||= description('form[*]')
    end

    def folio_catalog_links
      record.path("$.identification.catalogLinks[?@.catalog == 'folio']").search
    end
  end
end
