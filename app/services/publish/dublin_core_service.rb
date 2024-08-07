# frozen_string_literal: true

module Publish
  class DublinCoreService
    MODS_TO_DC_XSLT = Nokogiri::XSLT(File.new(File.expand_path("#{File.dirname(__FILE__)}/mods2dc.xslt")))
    XMLNS_OAI_DC = 'http://www.openarchives.org/OAI/2.0/oai_dc/'

    # @param [Nokogiri::XML::Document] the MODS XML to generate the DublinCore for.
    def initialize(public_cocina, constituents)
      desc_metadata_service = PublicDescMetadataService.new(public_cocina, constituents, include_access_conditions: false)
      @desc_md_xml = desc_metadata_service.ng_xml
    end

    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #    Should not be used for the Fedora DC datastream
    # @return [Nokogiri::XML::Document] the DublinCore XML document object
    def ng_xml
      MODS_TO_DC_XSLT.transform(desc_md_xml)
    end

    # @return [String] the DublinCore XML document object
    delegate :to_xml, to: :ng_xml

    private

    attr_reader :desc_md_xml
  end
end
