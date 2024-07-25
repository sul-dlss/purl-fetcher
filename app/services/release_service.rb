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
    write_meta_json
    purl.save!
    purl.produce_indexer_log_message
  end

  def write_meta_json
    if VersionedFilesService.versioned_files?(druid:)
      VersionedFilesService::Paths.new(druid:).meta_json_path.write(meta_json)
      write_purl_meta_json if Settings.features.legacy_purl
    else
      write_purl_meta_json
    end
  end

  private

  def write_purl_meta_json
    file_path = File.join(purl.purl_druid_path, 'meta.json')
    File.write(file_path, meta_json)
  end

  def meta_json
    {
      '$schemaVersion': 1,
      sitemap: purl.true_targets.include?('PURL sitemap'),
      searchworks: purl.true_targets.include?('Searchworks'),
      earthworks: purl.true_targets.include?('Earthworks')
    }.to_json
  end
end
