# Updates the Purl database record using information from the public xml
class PurlCocinaUpdater
  # @param [Purl] active_record
  # @param [Cocina::Models::Collection, Cocina::Models::DRO] cocina_object
  def initialize(active_record, cocina_object)
    @active_record = active_record
    @cocina_data = CocinaData.new(cocina_object)
  end

  attr_reader :active_record, :cocina_data

  delegate :collections, :releases, to: :cocina_data

  # rubocop:disable Metrics/MethodLength
  def attributes
    title = cocina_data.title
    if title.match?(/[\u{10000}-\u{10FFFF}]/)
      Honeybadger.notify('Unable to record title for item because it contains UTF8mb4 characters',
                         context: { title: title, druid: cocina_data.canonical_druid })
      title = nil
    end
    {
      druid: cocina_data.canonical_druid,
      title: title,
      object_type: cocina_data.object_type,
      catkey: cocina_data.catkey,
      published_at: Time.current,
      public_xml_attributes: { data: cocina_data.cocina_object&.to_json, data_type: 'cocina' },
      deleted_at: nil # ensure the deleted at field is nil (important for a republish of a previously deleted purl)
    }
  end
  # rubocop:enable Metrics/MethodLength

  def update
    active_record.attributes = attributes

    ##
    # Delete all of the collection assocations, and then add back ones in the
    # public xml
    active_record.refresh_collections(collections)

    # add the release tags, and reuse tags if already associated with this PURL
    active_record.refresh_release_tags(releases)

    active_record.save!
  end
end
