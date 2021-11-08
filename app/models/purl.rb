class Purl < ApplicationRecord
  has_and_belongs_to_many :collections
  has_many :release_tags, dependent: :destroy
  paginates_per 100
  max_paginates_per 10_000
  default_scope -> { order(:updated_at) }
  validates :druid, uniqueness: true

  scope :object_type, -> (object_type) { where object_type: object_type }

  scope :membership, lambda { |membership|
    case membership['membership']
    when 'collection'
      joins(:collections)
    when 'none'
      includes(:collections).where(collections: { id: nil })
    end
  }

  scope :status, lambda { |status|
    case status['status']
    when 'deleted'
      where.not deleted_at: nil
    when 'public'
      where deleted_at: nil
    end
  }

  scope :target, lambda { |target|
    return unless target['target'].present?

    includes(:release_tags).where(release_tags: { name: target['target'] })
  }

  scope :published, -> { where.not(published_at: nil) }

  ##
  # @param [Hash] filtering_params
  def self.with_filter(filtering_params)
    results = where(nil)
    filtering_params.each do |key, value|
      results = results.public_send(key, value) if value.present?
    end
    results
  end

  ##
  # Return true targets with always values only if the object is not deleted in
  # purl mount
  # @return [Array]
  def true_targets
    return [] unless deleted_at.nil?

    release_tags.where(release_type: true).map(&:name) | Settings.ALWAYS_SEND_TRUE_TARGET.to_a
  end

  ##
  # Convenience method for accessing false targets
  # @return [Array]
  def false_targets
    release_tags.where(release_type: false).map(&:name)
  end

  ##
  # Delete all of the collection assocations, and then add back ones from a
  # known valid list
  # @param [Array<String>] collections
  def refresh_collections(valid_collections)
    collections.delete_all
    valid_collections.each do |collection|
      collection_to_add = Collection.find_or_create_by(druid: collection)
      collections << collection_to_add unless collections.include?(collection_to_add)
    end
  end

  ##
  # Updates a Purl using information from the public xml document
  def update_from_public_xml!
    public_xml = PurlParser.new(path)

    return false unless public_xml.exists?

    self.druid = public_xml.canonical_druid
    self.title = public_xml.title
    self.object_type = public_xml.object_type
    self.catkey = public_xml.catkey

    ##
    # Delete all of the collection assocations, and then add back ones in the
    # public xml
    refresh_collections(public_xml.collections)

    # add the release tags, and reuse tags if already associated with this PURL
    [true, false].each do |type|
      public_xml.releases[type.to_s.to_sym].sort.uniq.each do |release|
        release_tags << ReleaseTag.for(self, release, type)
      end
    end

    self.published_at = public_xml.published_at
    self.deleted_at = nil # ensure the deleted at field is nil (important for a republish of a previously deleted purl)

    save!
  end

  ##
  # Specify an instance's `deleted_at` attribute which denotes when an object's
  # public xml is gone
  # @param [String] druid
  # @param [Time] `deleted_at` the time at which the PURL was deleted. If `nil`, it uses the current time.
  def self.mark_deleted(druid, deleted_at = nil)
    druid = "druid:#{druid}" unless druid.include?('druid:') # add the druid prefix if it happens to be missing
    purl = begin
             find_or_create_by(druid: druid) # either create a new druid record or get the existing one
           rescue ActiveRecord::RecordNotUnique
             retry
           end
    #  (in theory we should *always* have a previous druid here)
    purl.deleted_at = deleted_at.nil? ? Time.current : deleted_at
    purl.release_tags.delete_all
    purl.collections.delete_all
    purl.save
  end

  private

    ##
    # Path to the location of public xml document
    # @return [String]
    def path
      DruidTools::PurlDruid.new(
        druid,
        Settings.PURL_DOCUMENT_PATH
      ).path
    end
end
