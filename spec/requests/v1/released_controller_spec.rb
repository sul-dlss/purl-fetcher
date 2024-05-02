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

  describe 'PUT update' do
    before do
      allow(Racecar).to receive(:produce_sync)
    end

    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:data) { { actions: { 'index' => ['Searchworks'], 'delete' => ['Earthworks'] } }.to_json }

    context 'with an unknown item' do
      let(:druid) { 'druid:zz222yy2222' }

      it 'is not found' do
        put("/v1/released/#{druid}", params: data, headers:)
        expect(response).to have_http_status(:not_found)
        expect(Racecar).not_to have_received(:produce_sync)
      end
    end

    context 'with an existing item' do
      let(:purl_object) { create(:purl) }
      let(:druid) { purl_object.druid }
      let(:cocina_object) { JSON.parse(purl_object.public_json.data) }
      let(:expected_message_value) do
        {
          cocina: Cocina::Models.build(cocina_object),
          actions: {
            index: ['Searchworks'],
            delete: ['Earthworks']
          }
        }.to_json
      end

      it 'updates the purl with new data' do
        put("/v1/released/#{druid}", params: data, headers:)
        expect(response).to have_http_status(:accepted)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: druid, topic: 'purl-updates', value: expected_message_value)
      end
    end
  end
end
