set :application, 'purl-fetcher'
set :repo_url, 'https://github.com/sul-dlss/purl-fetcher.git'

# Default branch is :master so we need to update to main
if ENV['DEPLOY']
  set :branch, 'main'
else
  ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call
end

set :deploy_to, "/opt/app/lyberadmin/purl-fetcher"

# Default value for :linked_files is []
set :linked_files, %w{config/secrets.yml config/database.yml config/honeybadger.yml config/newrelic.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{log run tmp/pids tmp/cache tmp/sockets vendor/bundle public/system storage}

# Default value for keep_releases is 5
set :keep_releases, 5

# honeybadger_env otherwise defaults to rails_env
set :honeybadger_env, "#{fetch(:stage)}"

set :whenever_environment, fetch(:rails_env)
set :whenever_roles, [:cron]

after 'deploy:published', 'deploy:restart'
