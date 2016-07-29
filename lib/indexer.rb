require 'active_support/inflector'
require 'logger'
require 'stanford-mods'
require 'retries'
require 'druid-tools'
require 'action_controller'
require 'solr_methods'
require 'parser_methods'
require 'indexer_setup'

class Indexer

  include SolrMethods
  include ParserMethods
  include IndexerSetup

  # Class method: given a previous run_log entry, just reindex without finding
  # @param [Integer] run_log_id: The ID of a previous run log entry
  def self.reindex(run_log_id)
    Indexer.new.index_purls(output_file: RunLog.find(run_log_id).finder_filename)
  end

  # Finds all objects modified since the beginning of time.
  # Note: This is not the function to use for processing deletes
  def full_reindex
    find_and_index
  end

  # Finds all objects modified since the last time indexing was run
  # Note: This is not the function to use for processing deletes
  def index_since_last_run
    modified_at_or_later = RunLog.minutes_since_last_run_started
    find_and_index(mins_ago: modified_at_or_later)
  end

  # find and then index all public files changed since the specified number of minutes ago
  #  defaults to all if no time specified
  # Note: This is not the function to use for processing deletes
  #
  # @return [Hash] A hash listing number of docs indexed and the total run time {:count => n, :run_time => Seconds_It_Took_To_Run}
  #
  # Example:
  #   results = find_and_index(mins_ago: 100)
  def find_and_index(mins_ago: nil)
    results = {}
    if RunLog.currently_running?
      results[:note]="Job currently running. No action taken."
      log.info(results[:note])
    else
      start_time = Time.zone.now
      output_file=File.join(base_path_finder_log,"#{base_filename_finder_log}_#{Time.zone.now.strftime('%Y-%m-%d_%H-%M-%S')}.txt")
      run_log=RunLog.create(finder_filename: output_file, started: start_time)
      find_files(mins_ago: mins_ago, output_file: output_file)
      index_result = index_purls(output_file: output_file)
      end_time = Time.zone.now
      results[:run_time] = end_time - start_time
      run_log.total_druids=index_result[:count]
      run_log.num_errors=index_result[:error]
      run_log.ended = end_time
      run_log.save
    end
    results.merge(index_result)
  end

  # find all public files change since the specified number of minutes and store in the database
  #  if no time specified, finds all files
  # returns an integer with the number of files found
  # @param [Hash] mins_ago: The number of minutes to go back and find changes for (defaults to all time if left off)
  # @param [Hash] output_file: The filename location to store the results of the find operation
  # @param [String] The output file where the files were stored
  def find_files(params={})
    mins_ago = params[:mins_ago] || nil
    output_file = params[:output_file] || File.join(base_path_finder_log,"output.txt")
    if mins_ago
      search_string = "find #{purl_mount_location} -name public -type f -mmin -#{mins_ago}"
    else
      search_string = "locate \"#{purl_mount_location}/*public*\""
    end
    search_string += "> #{output_file}" # store the results in a tmp file so we don't have to keep everything in memory
    log.info("Finding public files")
    log.info(search_string)
    search_result=`#{search_string}`  # this is the big blocker line - send the find to unix and wait around until its done, at which point we have a file to read in
    return output_file
  end

  # indexes purls based on druids found in the output_file, going back to the specified minutes ago
  #  defaults to indexing all purls if no time specified
  # returns an integer with the number of files found
  # @param [Hash] output_file: The filename location of found purls to index from
  # @return [Hash] A hash with stats on the number of purls indexed, success and failure counts
  def index_purls(params={})
    output_file = params[:output_file] || File.join(base_path_finder_log,"output.txt")
    count=0
    error=0
    success=0
    log.info("Indexing #{output_file}")
    File.foreach(output_file) do |line| # line will be the full file path, including the druid tree, try and get the druid from this
      druid=get_druid_from_file_path(line)
      unless druid.blank?
        puts "Indexing #{druid}"
        result=add_to_solr(solrize_object(File.dirname(line)))
        result ? success+=1 : errors+=1
        count+=1
      end
      commit_to_solr if count % commit_every == 0 # every certain number of documents, issue a commit
    end
    commit_to_solr # do a final commit
    log.info("Attempted index of #{count} purls; #{success} succeeded, #{error} failed")
    {count: count, success: success, error: error}
  end

  # Finds all objects deleted from purl in the specified number of minutes and updates solr to reflect their deletion
  #
  # @return [Hash] A hash stating if the deletion was successful or not and an array of the docs {:success=> true/false, :docs => [{doc1},{doc2},...]}
  def remove_deleted_objects_from_solr(mins_ago: indexer_config.default_run_interval_in_minutes.to_i)
    # minutes_ago = ((Time.zone.now-mins_ago.minutes.ago)/60.0).ceil #use ceil to round up (2.3 becomes 3)
    query_path = Pathname(path_to_deletes_dir.to_s)
    # If we called the below statement with a /* on the end it would not return itself, however it would then throw errors on servers that don't yet have
    # a deleted object and thus don't have a .deletes dir
    deleted_objects = `find #{query_path} -mmin -#{mins_ago}`.split
    deleted_objects -= [query_path.to_s] # remove the deleted objects dir itself

    docs = []
    result = true # set this to true by default because if we get an empty list of documents, then it worked
    deleted_objects.each do |d_o|
      # Check to make sure that the object is really deleted
      druid = d_o.split(query_path.to_s + File::SEPARATOR)[1]
      if !druid.nil? && deleted?(druid)
        # delete_document(d_o) #delete the current document out of solr
        document={:id => ('druid:' + druid), indexer_config['deleted_field'].to_sym => 'true' }
        add_to_solr(document)
        docs << document
      end
      result = commit_to_solr unless docs.empty? # load in the new documents with the market to show they are deleted
    end
    { success: result, docs: docs }
  end

end
