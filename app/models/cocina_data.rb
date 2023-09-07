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

  # DSA adds the release tags from all collections this object is a member of.
  # What code consumes the release tags here.
  # https://github.com/sul-dlss/dor-services-app/blob/main/app/services/publish/metadata_transfer_service.rb#L22
  # @return [Hash] A hash of all trues and falses in the form of {:true => ['Target1', 'Target2'], :false => ['Target3', 'Target4']}
  def releases
    { true: [], false: [] }.tap do |releases|
      cocina_object.administrative.releaseTags.each do |tag|
        releases[tag.release ? :true : :false] << tag.to
      end
    end
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

  # @return [Array<String>] The collections the item is a member of
  def collections
    # see https://github.com/sul-dlss/dor-services-app/blob/f51bbcea710b7612f251a3922c5164ec69ba39aa/app/services/published_relationships_filter.rb#L31
    cocina_object.dro? ? cocina_object.structural.isMemberOf : []
  end

  private

  # from https://github.com/sul-dlss/dor-services-app/blob/f51bbcea710b7612f251a3922c5164ec69ba39aa/app/services/publish/public_xml_service.rb#L99
  def catalog_record_ids(catalog)
    Array(cocina_object.identification&.catalogLinks).filter_map { |link| link.catalogRecordId if link.catalog == catalog }
  end
end
