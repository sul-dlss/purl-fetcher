class CocinaData
  # @param [Cocina::Models::Collection, Cocina::Models::DRO]
  def initialize(cocina_object)
    @cocina_object = cocina_object
  end

  attr_reader :cocina_object

  # @return [String] The druid in the form of druid:pid
  def canonical_druid
    cocina_object.externalIdentifier
  end

  # @return [String] The catkey. An empty string is returned if there is no catkey
  def catkey
    catalog_record_ids('folio').first || catalog_record_ids('symphony').first || ''
  end

  # @return [String] The title of the object
  def title
    Cocina::Models::Builders::TitleBuilder.build(cocina_object.description.title)
  end

  # @return [String] The object type
  def object_type
    # See https://github.com/sul-dlss/dor-services-app/blob/main/app/services/publish/public_xml_service.rb#L91
    cocina_object.collection? ? 'collection' : 'item'
  end

  # @return [String] The content type
  def content_type
    Cocina::ToXml::ContentType.map(cocina_object.type) if cocina_object.dro?
  end

  # @return [Array<String>] The collections the item is a member of
  def collections
    # see https://github.com/sul-dlss/dor-services-app/blob/f51bbcea710b7612f251a3922c5164ec69ba39aa/app/services/published_relationships_filter.rb#L31
    cocina_object.dro? ? cocina_object.structural.isMemberOf : []
  end

  # @return [Array<String>] The constituent druids of this object (virtual object)
  def constituents
    return [] unless cocina_object.dro?

    cocina_object.structural.hasMemberOrders.first&.members || []
  end

  private

  # from https://github.com/sul-dlss/dor-services-app/blob/f51bbcea710b7612f251a3922c5164ec69ba39aa/app/services/publish/public_xml_service.rb#L99
  def catalog_record_ids(catalog)
    Array(cocina_object.identification&.catalogLinks).filter_map { |link| link.catalogRecordId if link.catalog == catalog }
  end
end
