require 'rails_helper'

RSpec.describe V1::ReleasedController do
  describe '#show' do
    let!(:release_tag) { create(:release_tag, :sitemap) }
    let(:purl) { release_tag.purl }

    it 'returns list of druids' do
      get '/released/PURL%20sitemap'
      expect(response.parsed_body).to eq [{ 'druid' => purl.druid, 'updated_at' => purl.updated_at.iso8601(3) }]
    end
  end
end
