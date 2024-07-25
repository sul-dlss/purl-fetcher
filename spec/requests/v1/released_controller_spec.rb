require 'rails_helper'

RSpec.describe V1::ReleasedController do
  describe '#show' do
    let!(:release_tag) { create(:release_tag, :sitemap) }
    let(:purl) { release_tag.purl }

    it 'returns list of druids' do
      get '/released/PURL%20sitemap'
      expect(response.parsed_body).to eq [{ 'druid' => purl.druid, 'updated_at' => purl.updated_at.iso8601(3) }]
    end

    context 'when sitemap release is false' do
      let!(:release_tag) { create(:release_tag, name: 'PURL sitemap', release_type: false) }
      let(:purl) { release_tag.purl }

      it 'returns empty list' do
        get '/released/PURL%20sitemap'
        expect(response.parsed_body).to be_empty
      end
    end
  end
end
