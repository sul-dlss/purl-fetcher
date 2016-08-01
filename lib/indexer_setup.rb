# setup methods used by the indexer and the Docs controller
module IndexerSetup

  def indexer_config
    PurlFetcher::Application.config.solr_indexing
  end

  def default_output_file
    File.join(base_path_finder_log,base_filename_finder_log)
  end
  
  # file location in the rails app to store the results of file system find operation
  def base_path_finder_log
    indexer_config['base_path_finder_log']
  end

  # the base filename of the file to stores the results of the find operation
  def base_filename_finder_log
    indexer_config['base_filename_finder_log']
  end

  def modified_at_or_later
    indexer_config['default_run_interval_in_minutes'].to_i.minutes.ago # default setting
  end

  def commit_every
    indexer_config['items_commit_every'].to_i
  end

  # Return the absolute path to the .deletes dir
  #
  # @return [Pathname] The absolute path
  def path_to_deletes_dir
    Pathname(File.join(purl_mount_location,indexer_config['deletes_dir']))
  end

  # Accessor to get the purl document cache path
  #
  # @return [String] The path
  def purl_mount_location
    indexer_config['purl_document_path']
  end

end
