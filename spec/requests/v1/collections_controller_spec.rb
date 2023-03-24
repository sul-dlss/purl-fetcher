require 'rails_helper'

RSpec.describe V1::CollectionsController do
  describe 'GET index' do
    it 'looks up Purl objects where object_type is collection' do
      get '/collections'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data.dig(:collections, 0, :druid)).to eq 'druid:ff111gg2222'
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get '/collections', params: { per_page: 1 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:collections, 0, :druid)).to eq 'druid:ff111gg2222'
        expect(data[:collections].count).to eq 1
      end

      it 'page' do
        get '/collections', params: { per_page: 1, page: 2 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:collections, 0, :druid)).to eq 'druid:gg111hh2222'
        expect(data[:collections].count).to eq 1
      end
    end
  end

  describe 'GET show' do
    it 'looks up a Purl by its druid' do
      get '/collections/druid:ff111gg2222'
      expect(response.status).to eq 200
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:druid]).to eq 'druid:ff111gg2222'
    end

    it 'raise a record not found error (returning a 404) when the collection druid is not found' do
      expect { get '/collections/druid:bogus' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET purls' do
    it 'purls for a selected collection' do
      get  '/collections/druid:ff111gg2222/purls'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data.dig(:purls, 0, :druid)).to eq 'druid:dd111ee2222'
      expect(data[:purls].count).to eq 3
    end
  end
end
