begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  puts 'Unable to load RuboCop.'
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  puts 'Unable to load rspec.'
end

desc 'Run continuous integration suite (tests, coverage, rubocop)'
task :ci do
  system('RAILS_ENV=test rake db:migrate')
  system('RAILS_ENV=test rake db:test:prepare')
  Rake::Task['spec'].invoke
  Rake::Task['rubocop'].invoke
end
