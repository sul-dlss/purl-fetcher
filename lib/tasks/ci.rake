begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  # no warning because we expect that rubocop will not be present in production
  # and we would prefer not to see a warning in cron output.
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  # no warning because we expect that rspec will not be present in production
  # and we would prefer not to see a warning in cron output.
end

desc 'Run continuous integration suite (tests, coverage, rubocop)'
task :ci do
  system('RAILS_ENV=test rake db:migrate')
  system('RAILS_ENV=test rake db:test:prepare')
  Rake::Task['spec'].invoke
  Rake::Task['rubocop'].invoke
end
