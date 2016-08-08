require 'rest_client'

desc 'Run continuous integration suite (tests, coverage, rubocop)'
task :ci do
   system('RAILS_ENV=test rake db:migrate')
   system('RAILS_ENV=test rake db:test:prepare')
   Rake::Task['rspec'].invoke
   Rake::Task['rubocop'].invoke
end

desc 'Run continuous integration suite without rubocop for travis'
task :travis_ci do
  system('RAILS_ENV=test rake db:migrate')
  system('RAILS_ENV=test rake db:test:prepare')
  Rake::Task['rspec'].invoke
end

desc 'Run rubocop on ruby files'
task :rubocop do
  if Rails.env.test? || Rails.env.development?
    begin
      require 'rubocop/rake_task'
      RuboCop::RakeTask.new
    rescue LoadError
      puts 'Unable to load RuboCop.'
    end
  end
end
