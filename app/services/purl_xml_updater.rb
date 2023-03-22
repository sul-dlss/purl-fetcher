# Updates the Purl database record using information from the public xml
class PurlXmlUpdater
  def initialize(active_record)
    @active_record = active_record
  end

  attr_reader :active_record

  delegate :collections, :releases, to: :public_xml

  def public_xml
    @public_xml ||= PurlParser.new(active_record.druid)
  end

  def preconditions_satisfied?
    public_xml.exists?
  end

  def attributes
    {
      druid: public_xml.canonical_druid,
      title: public_xml.title,
      object_type: public_xml.object_type,
      catkey: public_xml.catkey,
      published_at: public_xml.published_at,
      deleted_at: nil, # ensure the deleted at field is nil (important for a republish of a previously deleted purl)
      public_xml_attributes: { data: public_xml.public_xml.to_s }
    }
  end

  def update
    return false unless preconditions_satisfied?

    active_record.assign_attributes(attributes)

    ##
    # Delete all of the collection assocations, and then add back ones in the
    # public xml
    active_record.refresh_collections(collections)

    # add the release tags, and reuse tags if already associated with this PURL
    active_record.refresh_release_tags(releases)

    active_record.save!
  end
end
