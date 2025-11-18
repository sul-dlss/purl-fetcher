# frozen_string_literal: true

module Publish
  # Creates the descriptive XML that we display on purl.stanford.edu
  class PublicDescMetadataService
    attr_reader :cocina_object, :constituents, :include_access_conditions

    MODS_NS = 'http://www.loc.gov/mods/v3'

    # @param [Cocina::Models::Collection,Cocina::Models::DRO] cocina_object
    # @param [Array<Hash>] constituents a list of constituents (virtual object members) that are part of this object
    def initialize(cocina_object, constituents, include_access_conditions: true)
      @cocina_object = cocina_object
      @constituents = constituents
      @include_access_conditions = include_access_conditions
    end

    # @return [Nokogiri::XML::Document] A copy of the descriptiveMetadata of the object, to be modified
    def doc
      @doc ||= ToMods::Description.transform(cocina_object.description, cocina_object.externalIdentifier, identification: cocina_object.identification)
    end

    # @return [String] Public descriptive medatada XML
    # @params [Hash] _opts ({}) Rails sends args when rendering XML but we ignore them
    def to_xml(_opts = {})
      # NOTE: The gsub below handling carriage return characters is a workaround
      #        for a bug in libxml2 that the Nokogiri maintainers don't want to
      #        address in Rubyland. They recommend using `#gsub` on the string
      #        returned from `#to_xml`: https://github.com/sparklemotion/nokogiri/issues/1356
      ng_xml
        .to_xml
        .gsub('&#13;', "\r")
    end

    # @return [Nokogiri::XML::Document]
    def ng_xml
      @ng_xml ||= begin
        add_collection_reference!
        AccessConditions.add(public_mods: doc, access: cocina_object.access) if include_access_conditions
        add_constituent_relations!
        add_doi
        strip_comments!

        new_doc = Nokogiri::XML(doc.to_xml, &:noblanks)
        new_doc.encoding = 'UTF-8'
        new_doc
      end
    end

    private

    def strip_comments!
      doc.xpath('//comment()').remove
    end

    # Export DOI into the public descMetadata to allow PURL to display it
    def add_doi
      return unless cocina_object.dro? && cocina_object.identification.doi

      doi_node = doc.xpath('/xmlns:mods/xmlns:identifier[@type="doi"]').first
      if doi_node
        doi_node['displayLabel'] = 'DOI'
        doi_node.content = "https://doi.org/#{doi_node.content}" unless doi_node.content.starts_with?('https')
      else
        identifier = doc.create_element('identifier', xmlns: MODS_NS)
        identifier.content = "https://doi.org/#{cocina_object.identification.doi}"
        identifier['type'] = 'doi'
        identifier['displayLabel'] = 'DOI'
        doc.root << identifier
      end
    end

    # expand constituent relations into relatedItem references -- see JUMBO-18
    # @return [Void]
    def add_constituent_relations!
      constituents.each do |virtual_object_params|
        # create the MODS relation
        relatedItem = doc.create_element('relatedItem', xmlns: MODS_NS)
        relatedItem['type'] = 'host'
        relatedItem['displayLabel'] = 'Appears in'

        # load the title from the virtual object's DC.title
        titleInfo = doc.create_element('titleInfo', xmlns: MODS_NS)
        title = doc.create_element('title', xmlns: MODS_NS)
        title.content = virtual_object_params.fetch(:title)
        titleInfo << title
        relatedItem << titleInfo

        # point to the PURL for the virtual object
        location = doc.create_element('location', xmlns: MODS_NS)
        url = doc.create_element('url', xmlns: MODS_NS)
        url.content = purl_url(virtual_object_params.fetch(:id))
        location << url
        relatedItem << location

        # finish up by adding relation to public MODS
        doc.root << relatedItem
      end
    end

    def purl_url(druid)
      "https://#{Settings.purl.hostname}/#{druid.delete_prefix('druid:')}"
    end

    # Adds to desc metadata a relatedItem with information about the collection this object belongs to.
    # For use in published mods and mods-to-DC conversion.
    # @return [Void]
    def add_collection_reference!
      return if cocina_object.collection? || cocina_object.structural&.isMemberOf.blank?

      collections = cocina_object.structural&.isMemberOf

      remove_related_item_nodes_for_collections!

      Purl.where(druid: collections).find_each do |collection|
        add_related_item_node_for_collection! collection
      end
    end

    # Remove existing relatedItem entries for collections from descMetadata
    def remove_related_item_nodes_for_collections!
      doc.search('/mods:mods/mods:relatedItem[@type="host"]/mods:typeOfResource[@collection=\'yes\']',
                 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end
    end

    def add_related_item_node_for_collection!(collection)
      title_node         = Nokogiri::XML::Node.new('title', doc)
      title_node.content = collection.title

      title_info_node = Nokogiri::XML::Node.new('titleInfo', doc)
      title_info_node.add_child(title_node)

      # e.g.:
      #   <location>
      #     <url>http://purl.stanford.edu/rh056sr3313</url>
      #   </location>
      loc_node = doc.create_element('location', xmlns: MODS_NS)
      url_node = doc.create_element('url', xmlns: MODS_NS)
      url_node.content = purl_url(collection.druid)
      loc_node << url_node

      type_node = doc.create_element('typeOfResource', xmlns: MODS_NS)
      type_node['collection'] = 'yes'

      related_item_node = doc.create_element('relatedItem', xmlns: MODS_NS)
      related_item_node['type'] = 'host'

      related_item_node.add_child(title_info_node)
      related_item_node.add_child(loc_node)
      related_item_node.add_child(type_node)

      doc.root.add_child(related_item_node)
    end
  end
end
