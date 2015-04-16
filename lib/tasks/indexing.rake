require 'logger'

desc "Search for all objects modified within a 5 minutes and add them to solr"
task :index_changes_in_last_five_minutes => :environment do
  start_time = Time.now
  indexer = IndexerController.new
  result = indexer.index_all_modified_objects(mins_ago: 6) #adding one minute for slop
  indexing_log = Logger.new('log/indexing_rake_task.log')
  indexing_log.info("Running of rake task index_changes_in_last_five_minutes at #{start_time} returned a result of #{result}")
end

desc "Search for all objects modified since the start of the Unix Epoch and add them to solr"
task :index_since_beginning_of_unix_time => :environment do
  start_time = Time.now
  minutes_since_epoch = (Time.now.to_i/60.0).ceil
  indexer = IndexerController.new
  result = indexer.index_all_modified_objects(mins_ago: minutes_since_epoch + 1) #adding one minute for slop
  indexing_log = Logger.new('log/indexing_rake_task.log')
  indexing_log.info("Running of rake task index_since_beginning_of_unix_time at #{start_time} returned a result of #{result}")
end