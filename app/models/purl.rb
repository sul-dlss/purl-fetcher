class Purl < ApplicationRecord
  has_and_belongs_to_many :collections
  has_many :release_tags, dependent: :destroy
  has_one :public_json, dependent: :destroy

  accepts_nested_attributes_for :public_json, update_only: true
  paginates_per 100
  max_paginates_per 10_000
  default_scope -> { order(:updated_at) }
  validates :druid, uniqueness: true

  scope :object_type, -> (object_type) { where object_type: }

  scope :membership, lambda { |membership|
    case membership['membership']
    when 'collection'
      joins(:collections)
    when 'none'
      includes(:collections).where(collections: { id: nil })
    end
  }

  scope :status, lambda { |status|
    case status
    when 'deleted'
      where.not deleted_at: nil
    when 'public'
      where deleted_at: nil
    end
  }

  scope :target, lambda { |target|
    return unless target.present?

    includes(:release_tags).where(release_tags: { name: target })
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

  # Sends a message to the indexer_topic, which will cause this object to be reindexed
  def produce_indexer_log_message(async: false)
    if async
      Racecar.produce_async(value: as_public_json.to_json, topic: Settings.indexer_topic, key: druid)
    else
      Racecar.produce_sync(value: as_public_json.to_json, topic: Settings.indexer_topic, key: druid)
    end
  end

  def as_public_json
    data = if deleted?
             as_json(only: %i[druid])
           else
             as_json(only: %i[druid object_type title catkey], methods: %i[true_targets false_targets]).tap do |d|
               d[:collections] = collections.pluck(:druid)
             end
           end

    data[:updated_at] = updated_at&.iso8601
    data[:published_at] = published_at&.iso8601
    data[:deleted_at] = deleted_at&.iso8601
    data[:latest_change] = (deleted_at || published_at)&.iso8601

    data.compact_blank
  end

  def deleted?
    deleted_at.present?
  end

  ##
  # Release tags where the value is true or is one of the default targets. If the object has been deleted, it retuns blank.
  # This is consumed by
  # https://github.com/sul-dlss/searchworks_traject_indexer/blob/64359399e8f670ed414b1c56c648dc9b95ad6bad/lib/traject/readers/kafka_purl_fetcher_reader.rb#L26 # rubocop:disable Layout:LineLength
  # @return [Array]
  def true_targets
    return [] unless deleted_at.nil?

    release_tags.where(release_type: true).map(&:name) | Settings.ALWAYS_SEND_TRUE_TARGET.to_a
  end

  ##
  # Release tags with the value false.
  # This is consumed by https://github.com/sul-dlss/searchworks_traject_indexer/blob/64359399e8f670ed414b1c56c648dc9b95ad6bad/lib/traject/readers/kafka_purl_fetcher_reader.rb#L49
  # @return [Array]
  def false_targets
    release_tags.where(release_type: false).map(&:name)
  end

  # add the release tags, and reuse tags if already associated with this PURL
  def refresh_release_tags(releases)
    [true, false].each do |type|
      releases[type.to_s.to_sym].sort.uniq.each do |release|
        release_tags << ReleaseTag.for(self, release, type)
      end
    end
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
  # Specify an instance's `deleted_at` attribute which denotes when an object's
  # public xml is gone
  # @param [String] druid
  # @param [Time] `deleted_at` the time at which the PURL was deleted. If `nil`, it uses the current time.
  def self.mark_deleted(druid, deleted_at = nil)
    druid = "druid:#{druid}" unless druid.include?('druid:') # add the druid prefix if it happens to be missing
    purl = begin
             find_or_create_by(druid:) # either create a new druid record or get the existing one
           rescue ActiveRecord::RecordNotUnique
             retry
           end
    #  (in theory we should *always* have a previous druid here)
    purl.deleted_at = deleted_at.nil? ? Time.current : deleted_at
    purl.release_tags.delete_all
    purl.collections.delete_all
    purl.public_json&.delete
    purl.save
    purl
  end
end
