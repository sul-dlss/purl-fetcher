# Updates the Purl database record using information from the public xml
class PurlCocinaUpdater
  # @param [Purl] active_record
  # @param [Cocina::Models::Collection, Cocina::Models::DRO] cocina_object
  def initialize(active_record, cocina_object)
    @active_record = active_record
    @cocina_data = CocinaData.new(cocina_object)
  end

  attr_reader :active_record, :cocina_data

  delegate :collections, :releases, :virtual_object_constituents, to: :cocina_data

  def attributes
    {
      druid: cocina_data.canonical_druid,
      title: cocina_data.title,
      object_type: cocina_data.object_type,
      catkey: cocina_data.catkey,
      published_at: Time.current,
      deleted_at: nil # ensure the deleted at field is nil (important for a republish of a previously deleted purl)
    }
  end

  def update
    active_record.attributes = attributes

    ##
    # Delete all of the collection assocations, and then add back ones in the
    # public xml
    active_record.refresh_collections(collections)

    active_record.virtual_object_constituents = []
    virtual_object_constituents.each.with_index do |member, i|
      active_record.virtual_object_constituents.build(has_member: member, ordinal: i)
    end

    # add the release tags, and reuse tags if already associated with this PURL
    active_record.refresh_release_tags(releases)

    active_record.save!
  end
end
