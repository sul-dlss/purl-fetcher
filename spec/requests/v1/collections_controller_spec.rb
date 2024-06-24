require 'rails_helper'

RSpec.describe V1::CollectionsController do
  describe 'GET purls' do
    let(:collection) { create(:collection) }
    let!(:purls) do
      Array.new(3) { create(:purl, collections: [collection]) }
    end

    it 'purls for a selected collection' do
      get "/collections/#{collection.druid}/purls"
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:purls].pluck(:druid)).to match_array(purls.map(&:druid))
    end
  end
end
