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

  describe 'PUT update' do
    before do
      allow(Racecar).to receive(:produce_sync)
    end

    let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }
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
      let(:purl_druid_path) { purl_object.purl_druid_path }
      let(:meta_path) { Pathname.new(purl_druid_path) / 'meta.json' }

      before do
        FileUtils.rm_r(purl_druid_path) if File.directory?(purl_druid_path)
        FileUtils.mkdir_p(purl_druid_path)
      end

      it 'puts a Kafka message on the queue for indexing' do
        expect { put("/v1/released/#{druid}", params: data, headers:) }.to change(meta_path, :exist?)
          .from(false).to(true)
        expect(response).to have_http_status(:accepted)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: druid, topic: 'testing_topic', value: purl_object.as_public_json.to_json)
      end
    end

    context 'when no authorization token is provided' do
      it 'returns 401' do
        put("/v1/released/druid:zz222yy2222", params: data, headers: headers.except('Authorization'))

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
