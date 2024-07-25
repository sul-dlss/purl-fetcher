require 'rails_helper'

RSpec.describe V1::PurlsController do
  describe 'GET show' do
    let(:purl_object) { create(:purl) }
    let(:druid) { purl_object.druid }

    before do
      allow(FilesByMd5Service).to receive(:call).and_return([{ "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
                                                             { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }])
    end

    it 'displays the purl data' do
      get "/purls/#{druid}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("files_by_md5" => [
                                                { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
                                                { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
                                              ])

      expect(FilesByMd5Service).to have_received(:call).with(purl: purl_object)
    end

    context "when the druid was deleted" do
      let(:purl_object) { create(:purl, :deleted) }

      it 'returns a 404' do
        get "/purls/#{druid}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the druid doesn't exist" do
      it 'returns a 404' do
        get "/purls/zr240vm9599"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT /:druid/release_tags' do
    before do
      allow(Racecar).to receive(:produce_sync)
    end

    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }
    let(:data) { { actions: { 'index' => ['Searchworks'], 'delete' => ['Earthworks'] } }.to_json }

    context 'with an unknown item' do
      let(:druid) { 'druid:zz222yy2222' }

      it 'is not found' do
        put("/v1/purls/#{druid}/release_tags", params: data, headers:)
        expect(response).to have_http_status(:not_found)
        expect(Racecar).not_to have_received(:produce_sync)
      end
    end

    context 'with an existing unversioned item' do
      let(:purl_object) { create(:purl) }
      let(:druid) { purl_object.druid }
      let(:purl_druid_path) { purl_object.purl_druid_path }
      let(:meta_path) { Pathname.new(purl_druid_path) / 'meta.json' }

      before do
        FileUtils.rm_r(purl_druid_path) if File.directory?(purl_druid_path)
        FileUtils.mkdir_p(purl_druid_path)
      end

      after do
        FileUtils.rm_rf(purl_druid_path)
      end

      it 'puts a Kafka message on the queue for indexing' do
        expect { put("/v1/purls/#{druid}/release_tags", params: data, headers:) }.to change(meta_path, :exist?)
          .from(false).to(true)
        expect(response).to have_http_status(:accepted)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: druid, topic: 'testing_topic', value: purl_object.as_public_json.to_json)
      end
    end

    context 'with an existing versioned item' do
      let(:purl_object) { create(:purl, druid:) }
      let(:druid) { 'druid:bc123df4567' }
      let(:purl_druid_path) { purl_object.purl_druid_path }
      let(:meta_path) { Pathname.new(purl_druid_path) / 'meta.json' }

      let(:stacks_path) { Pathname.new('tmp/stacks') }
      let(:stacks_meta_path) { stacks_path / 'bc/123/df/4567/bc123df4567/versions/meta.json' }

      before do
        allow(Settings.features).to receive(:legacy_purl).and_return(true)
        allow(Settings.filesystems).to receive(:stacks_root).and_return(stacks_path.to_s)

        FileUtils.mkdir_p(purl_druid_path)
        FileUtils.mkdir_p(stacks_meta_path.dirname)
      end

      after do
        FileUtils.rm_rf(stacks_path)
        FileUtils.rm_rf(purl_druid_path)
      end

      it 'puts a Kafka message on the queue for indexing' do
        expect { put("/v1/purls/#{druid}/release_tags", params: data, headers:) }.to change(meta_path, :exist?)
          .from(false).to(true).and change(stacks_meta_path, :exist?).from(false).to(true)
        expect(response).to have_http_status(:accepted)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: druid, topic: 'testing_topic', value: purl_object.as_public_json.to_json)
      end
    end

    context 'when no authorization token is provided' do
      it 'returns 401' do
        put("/v1/purls/druid:zz222yy2222/release_tags", params: data, headers: headers.except('Authorization'))

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
