# Updates the Purl database record using information from the public xml
class PurlCocinaUpdater
  UTF8_4BYTE_REGEX = /[\u{10000}-\u{10FFFF}]/

  def self.update(...)
    new(...).update
  end

  # @param [Purl] active_record
  # @param [Cocina::Models::Collection, Cocina::Models::DRO] cocina_object
  # @param [Integer] version
  def initialize(active_record, cocina_object, version: nil)
    @active_record = active_record
    @cocina_data = CocinaData.new(cocina_object)
    @version = version
    Honeybadger.context({ cocina_object: cocina_object.to_h })
  end

  attr_reader :active_record, :cocina_data, :version

  delegate :collections, :constituents, to: :cocina_data

  def attributes
    title = cocina_data.title
    if title&.match?(UTF8_4BYTE_REGEX)
      Honeybadger.notify('Unable to record title for item because it contains UTF8mb4 characters',
                         context: { title:, druid: cocina_data.canonical_druid })
      title = title.gsub(UTF8_4BYTE_REGEX, "?")
    end
    {
      druid: cocina_data.canonical_druid,
      title:,
      object_type: cocina_data.object_type,
      content_type: cocina_data.content_type,
      catkey: cocina_data.catkey,
      published_at: Time.current,
      cocina_object: cocina_data.cocina_object,
      version:,
      deleted_at: nil # ensure the deleted at field is nil (important for a republish of a previously deleted purl)
    }
  end

  def update
    active_record.attributes = attributes

    ##
    # Delete the assocations, and then add back ones in the Cocina
    active_record.refresh_collections(collections)
    active_record.constituent_memberships = constituents.map.with_index do |druid, sort_order|
      ConstituentMembership.new(child: Purl.find_or_create_by(druid:), sort_order:)
    end

    active_record.save!
  end
end
