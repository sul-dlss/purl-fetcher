set :application, 'purl-fetcher'
set :repo_url, 'https://github.com/sul-dlss/purl-fetcher.git'

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call unless ENV['DEPLOY']

set :deploy_to, "/opt/app/lyberadmin/purl-fetcher"

# Default value for :linked_files is []
set :linked_files, %w{config/secrets.yml config/database.yml config/honeybadger.yml config/newrelic.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{log run tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# Default value for keep_releases is 5
set :keep_releases, 5

# honeybadger_env otherwise defaults to rails_env
set :honeybadger_env, "#{fetch(:stage)}"

after 'deploy:published', 'deploy:restart'
  
