require 'rails_helper'

RSpec.describe V1::PurlsController do
  describe 'GET show' do
    let(:purl_object) { create(:purl) }
    let(:druid) { purl_object.druid }

    it 'displays the purl data' do
      get "/purls/#{druid}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("files_by_md5" => [
                                                { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
                                                { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
                                              ])
    end

    context "when the druid doesn't exist" do
      it 'returns a 404' do
        get "/purls/zr240vm9599"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST update' do
    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }
    let(:title) { "The Information Paradox for Black Holes" }
    let(:cocina_object) do
      build(:dro_with_metadata, id: druid, title:,
                                collection_ids: ['druid:xb432gf1111'])
        .new(administrative: {
               hasAdminPolicy: "druid:hv992ry2431"
             },
             created: Time.now.utc.iso8601,
             modified: Time.now.utc.iso8601)
    end
    let(:data) { cocina_object.to_json }
    let(:druid) { 'druid:zz222yy2222' }

    context 'with cocina json' do
      before do
        allow(PurlCocinaUpdater).to receive(:update)
      end

      context 'with a new item' do
        it 'creates a new purl entry' do
          expect do
            post "/purls/#{druid}", params: data, headers:
          end.to change(Purl, :count).by(1)
          expect(response).to have_http_status(:accepted)
          expect(PurlCocinaUpdater).to have_received(:update)
            .with(an_instance_of(Purl), an_instance_of(Cocina::Models::DRO))

          purl_object = Purl.find_by!(druid:)

          public_cocina_filepath = File.join(purl_object.purl_druid_path, 'cocina.json')
          expect(JSON.parse(File.read(public_cocina_filepath))).to eq Cocina::Models.without_metadata(cocina_object).to_h.with_indifferent_access

          public_xml_filepath = File.join(purl_object.purl_druid_path, 'public')
          expect(File.exist?(public_xml_filepath)).to be true
        end
      end

      context 'with an existing item' do
        let(:purl_object) { create(:purl) }
        let(:druid) { purl_object.druid }

        it 'updates the purl with new data' do
          post("/purls/#{druid}", params: data, headers:)
          expect(PurlCocinaUpdater).to have_received(:update)
            .with(an_instance_of(Purl), an_instance_of(Cocina::Models::DRO))

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
    let!(:purl_object) { create(:purl, druid: 'druid:bb050dj7711') }
    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }

    before do
      allow(Racecar).to receive(:produce_sync)
    end

    context 'with valid authorization token' do
      before do
        FileUtils.mkdir_p('tmp/stacks/bb/050/dj/7711/')
        File.write('tmp/stacks/bb/050/dj/7711/file3.txt', 'hello world')
      end

      it 'marks the purl as deleted and removes files' do
        expect(File).to exist('tmp/stacks/bb/050/dj/7711/file3.txt')
        delete('/purls/bb050dj7711', headers:)
        expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
        expect(Racecar).to have_received(:produce_sync)
          .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
        expect(File).not_to exist('tmp/stacks/bb/050/dj/7711/file3.txt')
      end
    end

    context 'when no authorization token is provided' do
      it 'returns 401' do
        delete('/purls/bb050dj7711', headers: headers.except('Authorization'))

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
