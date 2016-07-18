# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'net/http'
require 'capybara/rspec'
require 'capybara/rails'
require 'json'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include Capybara::DSL

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
end

class FetcherTester
  include Fetcher
end

class IndexerTester
  include Indexer
end

class FixtureData
  # Items
  @@not_accessioned_druid = ['druid:aa000bb0000']
  @@stafford_items_druids = ['druid:jf275fd6276', 'druid:nz353cp1092', 'druid:tc552kq0798', 'druid:th998nk0722', 'druid:ww689vs6534']
  @@revs_items_druids = ['druid:bb001zc5754', 'druid:bb004bn8654', 'druid:bb013sq9803', 'druid:bb014bd3784', 'druid:bb023nj3137', 'druid:bb027yn4436', 'druid:bb048rn5648', 'druid:bb113tm9924']
  @@items_druids = @@stafford_items_druids + @@revs_items_druids

  # Collections
  @@top_level_revs_collection_druid = 'druid:nt028fd5773'
  @@revs_subcollection_druid = 'druid:wy149zp6932'
  @@stafford_collection_druids = ['druid:yg867hg1375']
  @@revs_collection_druids = [@@top_level_revs_collection_druid, @@revs_subcollection_druid, 'druid:yt502zj0924']
  @@accessioned_collection_druids = @@stafford_collection_druids + @@revs_collection_druids

  @@all_collection_druids = @@accessioned_collection_druids + @@not_accessioned_druid

  def accessioned_druids
    @@accessioned_collection_druids + @@items_druids
  end

  def all_druids
    accessioned_druids + not_accessioned_druid
  end

  def not_accessioned_druid
    @@not_accessioned_druid
  end

  def all_collection_druids
    @@all_collection_druids
  end

  def accessioned_collection_druids
    @@accessioned_collection_druids
  end

  def stafford_collections_druids
    @@stafford_collection_druids
  end

  def revs_collections_druids
    @@revs_collection_druids
  end

  def revs_subcollection_druid
    @@revs_subcollection_druid
  end

  def top_level_revs_collection_druid
    @@top_level_revs_collection_druid
  end

  def revs_items_druids
    @@revs_items_druids
  end

  def stafford_items_druids
    @@stafford_items_druids
  end

  def all_items_druids
    @@items_druids = @@stafford_items_druids
  end

  def get_response(url)
    Net::HTTP.get_response(URI.parse(url))
  end

  def get_response_body(url)
    JSON.parse(get_response(url).body)
  end
end
