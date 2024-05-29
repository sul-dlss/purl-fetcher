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
    return unless Settings.features.write_meta_json

    file_path = File.join(purl.purl_druid_path, 'meta.json')
    File.write(file_path, meta_json(purl))
  end

  def self.meta_json(purl)
    {
      sitemap: purl.true_targets.include?('PURL sitemap'),
      searchworks: purl.true_targets.include?('Searchworks'),
      earthworks: purl.true_targets.include?('Earthworks')
    }.to_json
  end
end
