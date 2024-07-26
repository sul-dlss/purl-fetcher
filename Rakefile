# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)

Rails.application.load_tasks

task(:default).clear
task default: :ci

task generate_meta_json: :environment do
  Purl.status('public').find_each.with_index do |purl, index|
    ReleaseService.new(purl).write_meta_json
    puts index if (index % 50_000).zero?
  rescue Errno::ENOENT
    puts "No document directory for: #{purl.druid}"
  end
end
