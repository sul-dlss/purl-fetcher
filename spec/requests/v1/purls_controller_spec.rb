require 'rails_helper'

RSpec.describe V1::PurlsController do
  describe 'POST update' do
    context 'with cocina json' do
      before do
        allow(Racecar).to receive(:produce_sync)
      end

      let(:headers) { { 'Content-Type' => 'application/json' } }
      let(:cocina_object) do
        build(:dro_with_metadata, id: druid, title: "The Information Paradox for Black Holes",
                                  collection_ids: ['druid:xb432gf1111'])
          .new(administrative: {
                 hasAdminPolicy: "druid:hv992ry2431",
                 releaseTags: [
                   { to: 'Searchworks', release: true },
                   { to: 'Earthworks', release: false }
                 ]
               })
      end
      let(:data) { cocina_object.to_json }
      let(:expected_message_value) { Cocina::Models.without_metadata(cocina_object).to_json }

      context 'with a new item' do
        let(:druid) { 'druid:zz222yy2222' }

        it 'creates a new purl entry' do
          expect do
            post "/purls/#{druid}", params: data, headers: headers
          end.to change(Purl, :count).by(1)
          expect(response).to have_http_status(:accepted)
          expect(Racecar).to have_received(:produce_sync)
            .with(key: String, topic: 'purl-update', value: expected_message_value)
        end
      end

      context 'with an existing item' do
        let(:purl_object) { create(:purl) }
        let(:druid) { purl_object.druid }

        it 'updates the purl with new data' do
          post "/purls/#{druid}", params: data, headers: headers
          expect(Racecar).to have_received(:produce_sync)
            .with(key: druid, topic: 'purl-update', value: expected_message_value)

          expect(response).to have_http_status(:accepted)
        end
      end
    end
  end

  describe 'DELETE delete' do
    let(:purl_object) { create(:purl) }

    before do
      allow(Racecar).to receive(:produce_sync)
      purl_object.update(druid: 'druid:bb050dj7711')
    end

    it 'marks the purl as deleted' do
      delete '/purls/bb050dj7711'
      expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
      expect(Racecar).to have_received(:produce_sync)
        .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
    end
  end
end
