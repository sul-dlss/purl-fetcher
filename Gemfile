source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.0"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

gem 'rake', '~> 13'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

gem 'kaminari' # for pagination

gem 'honeybadger'
gem 'okcomputer' # for monitoring

gem 'config'

group :test do
  gem 'capybara'
  gem 'rspec-rails', '~> 7.1'
  gem 'simplecov', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :production do
  gem 'mysql2'
  gem 'newrelic_rpm'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'dlss-capistrano', '~> 5.1'
end

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  # Use sqlite3 as the database for Active Record
  gem "sqlite3", "~> 1.4"
end

gem 'cocina-models', '~> 0.98.0'

gem "racecar"

gem 'whenever', require: false

gem 'jwt' # json web token

gem "druid-tools", "~> 3.0"
