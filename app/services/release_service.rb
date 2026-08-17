class ReleaseService
  # @param [Purl] purl
  # @param [Hash<String, Array<String>>] where to release to. Note that even when this is empty, we release to the "always_send_true_targets"
  def self.release(purl, actions)
    new(purl).release(actions)
  end

  attr_reader :purl

  delegate :druid, to: :purl

  def initialize(purl)
    @purl = purl
  end

  def release(actions)
    # add the release tags, and reuse tags if already associated with this PURL
    purl.refresh_release_tags(actions)
    purl.save!

    write_meta_json

    IndexerLogWriter.produce_indexer_log_message(purl, async: false)
  end

  def write_meta_json
    VersionedFilesService::Paths.new(druid:).meta_json_path.write(meta_json)
  end

  private

  def currently_released_to
    purl.currently_released_to
  end

  def meta_json
    {
      '$schemaVersion': 1,
      sitemap: currently_released_to.sitemap?,
      searchworks: currently_released_to.searchworks?,
      earthworks: currently_released_to.earthworks?
    }.to_json
  end
end
