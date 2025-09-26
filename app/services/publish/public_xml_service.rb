# frozen_string_literal: true

module Publish
  # Exports the full object XML that we display on purl.stanford.edu
  class PublicXmlService
    # @param [Cocina::Models::DRO, Cocina::Models::Collection] public_cocina a cocina object stripped of non-public data
    # @param [ThumbnailService] thumbnail_service
    def initialize(public_cocina:, thumbnail_service:)
      @public_cocina = public_cocina
      @thumbnail_service = thumbnail_service
    end

    # @raise [Dor::DataError]
    # rubocop:disable Metrics/AbcSize
    # @params [Hash] _opts ({}) Rails sends args when rendering XML but we ignore them
    def to_xml(_opts = {})
      pub = Nokogiri::XML('<publicObject/>').root
      pub['id'] = public_cocina.externalIdentifier
      pub['published'] = Time.now.utc.xmlschema
      pub['publishVersion'] = "cocina-models/#{Cocina::Models::VERSION}"
      pub.add_child(public_identity_metadata.root) # add in modified identityMetadata datastream
      pub.add_child(public_content_metadata.root) if public_content_metadata.xpath('//resource').any?
      pub.add_child(public_rights_metadata)
      pub.add_child(public_relationships.root)

      pub.add_child(PublicDescMetadataService.new(public_cocina, constituents).ng_xml.root)
      # Note we cannot base this on if an individual object has release tags or not, because the collection may cause one to be generated for an item,
      # so we need to calculate it and then look at the final result.

      thumb = @thumbnail_service.thumb
      pub.add_child(Nokogiri("<thumb>#{thumb}</thumb>").root) unless thumb.nil?
      new_pub = Nokogiri::XML(pub.to_xml, &:noblanks)
      new_pub.encoding = 'UTF-8'
      new_pub.to_xml
    end
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :public_cocina

    def constituents
      @constituents ||= VirtualObject.for(druid: public_cocina.externalIdentifier)
    end

    def public_relationships
      Nokogiri::XML(PublishedRelationshipsFilter.new(public_cocina, constituents).xml)
    end

    def public_rights_metadata
      @public_rights_metadata ||= RightsMetadata.new(public_cocina, release_date).create
    end

    def release_date
      return unless public_cocina.dro? && public_cocina.access.embargo

      public_cocina.access.embargo.releaseDate.utc.iso8601
    end

    SYMPHONY = 'symphony'
    FOLIO = 'folio'

    # catkeys are used by PURL
    # objectType is used by purl-fetcher
    # objectLabel is used by https://github.com/sul-dlss/searchworks_traject_indexer/blob/72195e34e364fb2c191c40b23fe51679746f6419/lib/public_xml_record.rb#L34
    # Barcode and sourceId are used by the CdlController in Stacks https://github.com/sul-dlss/stacks/blame/master/app/controllers/cdl_controller.rb#L121
    def public_identity_metadata
      nodes = catalog_record_ids(SYMPHONY).map { |catkey| "  <otherId name=\"catkey\">#{catkey}</otherId>" }
      catalog_record_ids(FOLIO).each do |folio_instance_hrid|
        nodes << "  <otherId name=\"folio_instance_hrid\">#{folio_instance_hrid}</otherId>"
      end
      nodes << "  <sourceId source=\"sul\">#{public_cocina.identification.sourceId}</sourceId>" if public_cocina.identification.sourceId.present?
      nodes << "  <otherId name=\"barcode\">#{public_cocina.identification.barcode}</otherId>" if public_cocina.dro? && public_cocina.identification.barcode

      Nokogiri::XML(
        <<~XML
          <identityMetadata>
            <objectType>#{public_cocina.collection? ? 'collection' : 'item'}</objectType>
            <objectLabel>#{public_cocina.label}</objectLabel>
            #{nodes.join("\n")}
          </identityMetadata>
        XML
      )
    end

    def catalog_record_ids(catalog)
      Array(public_cocina.identification&.catalogLinks).filter_map { |link| link.catalogRecordId if link.catalog == catalog }
    end

    # @return [Nokogiri::XML::Document] sanitized for public consumption
    def public_content_metadata
      return Nokogiri::XML::Document.new unless public_cocina.dro?

      @public_content_metadata ||= ResourceIdRewriter.call(
        Cocina::ToXml::ContentMetadataGenerator.generate(
          druid: public_cocina.externalIdentifier,
          structural: public_cocina.structural,
          type: public_cocina.type
        )
      )
    end
  end
end
