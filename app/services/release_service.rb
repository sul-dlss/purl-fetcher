class ReleaseService
  # @param [Purl] purl
  # @param [Hash<String, Array<String>>] where to release to. Note that even when this is empty, we release to the "always_send_true_targets"
  def self.release(purl, actions)
    # add the release tags, and reuse tags if already associated with this PURL
    purl.refresh_release_tags(actions)
    write_meta_json(purl)
    purl.save!
    purl.produce_indexer_log_message
  end

  def self.write_meta_json(purl)
    if VersionedFilesService.versioned_files?(druid: purl.druid)
      VersionedFilesService::Paths.new(druid: purl.druid).meta_json_path.write(meta_json(purl))
      write_purl_meta_json(purl) if Settings.features.legacy_purl
    else
      write_purl_meta_json(purl)
    end
  end

  def self.write_purl_meta_json(purl)
    file_path = File.join(purl.purl_druid_path, 'meta.json')
    File.write(file_path, meta_json(purl))
  end
  private_class_method :write_purl_meta_json

  def self.meta_json(purl)
    {
      sitemap: purl.true_targets.include?('PURL sitemap'),
      searchworks: purl.true_targets.include?('Searchworks'),
      earthworks: purl.true_targets.include?('Earthworks')
    }.to_json
  end
end
