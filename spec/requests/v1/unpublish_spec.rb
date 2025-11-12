require 'rails_helper'

RSpec.describe 'Unpublish a Purl' do
  let(:druid) { 'druid:bb050dj7711' }
  let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }

  before do
    allow(Racecar).to receive(:produce_sync)
  end

  context 'with valid authorization token' do
    context 'when the druid exists' do
      let!(:purl_object) { create(:purl, druid:) }

      context 'when versioned files is enabled' do
        let(:object_store) { ObjectStore.new(druid:) }

        before do
          object_store.write_content(md5: '5b79c8570b7ef582735f912aa24ce5f2', file: 'hello world')
          object_store.write_cocina(version: 1, json: 'hello cocina')
          object_store.write_public_xml(version: 1, xml: 'hello public xml')
          object_store.write_versions(json: { versions: { '1': { date: '2024' } }, head: "1" }.to_json)
        end

        it 'marks the purl as deleted and removes files' do
          delete("/purls/#{druid}", headers:)

          expect(response).to have_http_status(:success)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect { object_store.read_versions }.to raise_error(ObjectStore::NotFoundError)
          expect { object_store.read_cocina(version: 1) }.to raise_error(ObjectStore::NotFoundError)
          expect { object_store.read_public_xml(version: 1) }.to raise_error(ObjectStore::NotFoundError)
          expect { object_store.read_content(md5: '5b79c8570b7ef582735f912aa24ce5f2', response_target: StringIO.new) }.to raise_error(ObjectStore::NotFoundError)
        end
      end

      context "when the druid was already deleted" do
        let(:purl_object) { create(:purl, :deleted, druid:) }

        it 'returns a 409' do
          delete("/purls/#{druid}", headers:)

          expect(response).to have_http_status(:conflict)
        end
      end
    end

    context "when the druid didn't exist" do
      it 'returns a 409' do
        delete("/purls/#{druid}", headers:)

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  context 'when no authorization token is provided' do
    before { create(:purl, druid:) }

    it 'returns 401' do
      delete "/purls/#{druid}", headers: headers.except('Authorization')

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
