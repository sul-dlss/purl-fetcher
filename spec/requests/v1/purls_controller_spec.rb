require 'rails_helper'

RSpec.describe V1::PurlsController do
  describe 'GET show' do
    let!(:release_tag) { create(:release_tag, :sitemap) }
    let(:purl_object) { release_tag.purl }
    let(:druid) { purl_object.druid }

    it 'displays the purl data' do
      get "/purls/#{druid}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("true_targets" => ["PURL sitemap", "SearchWorksPreview", "ContentSearch"])
    end
  end

  describe 'POST update' do
    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }
    let(:title) { "The Information Paradox for Black Holes" }
    let(:cocina_object) do
      build(:dro_with_metadata, id: druid, title:,
                                collection_ids: ['druid:xb432gf1111'])
        .new(administrative: {
               hasAdminPolicy: "druid:hv992ry2431",
               releaseTags: [
                 { to: 'Searchworks', release: true, what: 'self' },
                 { to: 'Earthworks', release: false, what: 'self' }
               ]
             },
             created: Time.now.utc.iso8601,
             modified: Time.now.utc.iso8601)
    end
    let(:data) { cocina_object.to_json }
    let(:druid) { 'druid:zz222yy2222' }

    context 'with cocina json' do
      before do
        allow(Racecar).to receive(:produce_sync)
      end

      let(:expected_message_value) do
        {
          cocina: Cocina::Models.build(cocina_object),
          actions: {
            index: ['Searchworks'],
            delete: ['Earthworks']
          }
        }.to_json
      end

      context 'with a new item' do
        it 'creates a new purl entry' do
          expect do
            post "/purls/#{druid}", params: data, headers:
          end.to change(Purl, :count).by(1)
          expect(response).to have_http_status(:accepted)
          expect(Racecar).to have_received(:produce_sync)
            .with(key: String, topic: 'purl-updates', value: expected_message_value)
        end
      end

      context 'with a 4byte utf-8 character in the title' do
        let(:title) { "𒀒 is an odd symbol" }

        it 'creates a new purl entry' do
          expect do
            post "/purls/#{druid}", params: data, headers:
          end.not_to change(Purl, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(Racecar).not_to have_received(:produce_sync)
        end
      end

      context 'with an existing item' do
        let(:purl_object) { create(:purl) }
        let(:druid) { purl_object.druid }

        it 'updates the purl with new data' do
          post("/purls/#{druid}", params: data, headers:)
          expect(Racecar).to have_received(:produce_sync)
            .with(key: druid, topic: 'purl-updates', value: expected_message_value)

          expect(response).to have_http_status(:accepted)
        end
      end
    end

    context 'when no authorization token is provided' do
      it 'returns 401' do
        post "/purls/#{druid}", params: data, headers: headers.except('Authorization')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE delete' do
    let(:purl_object) { create(:purl) }
    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }

    before do
      allow(Racecar).to receive(:produce_sync)
      purl_object.update(druid: 'druid:bb050dj7711')
    end

    it 'marks the purl as deleted' do
      delete('/purls/bb050dj7711', headers:)
      expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
      expect(Racecar).to have_received(:produce_sync)
        .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
    end

    context 'when no authorization token is provided' do
      it 'returns 401' do
        delete('/purls/bb050dj7711', headers: headers.except('Authorization'))

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
