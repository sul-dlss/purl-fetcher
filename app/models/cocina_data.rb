class CocinaData
  # @param [Hash] data_hash a parsed Cocina JSON document (Collection or DRO) with string keys
  def initialize(data_hash)
    @data_hash = data_hash
  end

  attr_reader :data_hash

  # @return [String] The druid in the form of druid:pid
  def canonical_druid
    data_hash['externalIdentifier']
  end

  # @return [String] The catkey. An empty string is returned if there is no catkey
  def catkey
    catalog_record_ids('folio').first || catalog_record_ids('symphony').first || ''
  end

  # @return [String] The title of the object
  def title
    CocinaDisplay::CocinaRecord.new(data_hash).display_title
  end

  # @return [String] The object type
  def object_type
    collection? ? 'collection' : 'item'
  end

  # @return [String] The content type
  def content_type
    Cocina::ToXml::ContentType.map(data_hash['type']) if dro?
  end

  # @return [Array<String>] The collections the item is a member of
  def collections
    dro? ? Array(data_hash.dig('structural', 'isMemberOf')) : []
  end

  # @return [Array<String>] The constituent druids of this object (virtual object)
  def constituents
    return [] unless dro?

    Array(data_hash.dig('structural', 'hasMemberOrders')&.first&.dig('members'))
  end

  private

  def collection?
    Cocina::Models::Collection::TYPES.include?(data_hash['type'])
  end

  def dro?
    Cocina::Models::DRO::TYPES.include?(data_hash['type'])
  end

  def catalog_record_ids(catalog)
    Array(data_hash.dig('identification', 'catalogLinks')).filter_map { |link| link['catalogRecordId'] if link['catalog'] == catalog }
  end
end
