set :bundle_without, %w(test deployment development).join(' ')

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
