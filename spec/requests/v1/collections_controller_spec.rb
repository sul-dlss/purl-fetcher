require 'rails_helper'

RSpec.describe V1::CollectionsController do
  describe 'GET purls' do
    it 'purls for a selected collection' do
      get  '/collections/druid:ff111gg2222/purls'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data.dig(:purls, 0, :druid)).to eq 'druid:dd111ee2222'
      expect(data[:purls].count).to eq 3
    end
  end
end
