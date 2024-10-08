# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Load rubyconfig gem so that we have access to env-specific settings
require 'config'

Config.load_and_set_settings(Config.setting_files('config', 'production'))

# Purging transfer files that have become orphaned to avoid filling storage.
every 1.days do
  runner "`find #{Settings.filesystems.transfer} -type f -mtime +7 -exec rm {} +`"
end
