require 'rails_helper'

RSpec.describe 'Withdraw a user version' do
  # We override this let variable in other contexts, so we don't want it in the before block.
  let!(:purl_object) { create(:purl, druid:) } # rubocop:disable RSpec/LetSetup
  let(:druid) { 'druid:bc123df4567' }

  let(:versions_path) { "bc/123/df/4567/bc123df4567/versions" }
  let(:s3_bucket) { Aws::S3::Bucket.new(Settings.s3.bucket, client: s3_client) }
  let(:s3_client) { S3ClientFactory.create_client }

  let(:object) do
    VersionedFilesService::Object.new(druid)
  end

  let(:versions_manifest_key) { "#{versions_path}/versions.json" }

  let(:versions_data) do
    {
      versions: {
        '1' => { state: 'available', date: DateTime.now.iso8601 },
        '2' => { state: 'available', date: DateTime.now.iso8601 }
      },
      head: 2
    }
  end

  let(:read_version_data) do
    resp = s3_client.get_object(
      bucket: Settings.s3.bucket,
      key: versions_manifest_key
    )
    JSON.parse(resp.body.read)
  end

  before do
    s3_client.put_object(
      bucket: Settings.s3.bucket,
      key: versions_manifest_key,
      body: versions_data.to_json
    )
  end

  after do
    s3_bucket.clear!
  end

  describe 'PUT /v1/purls/:druid/versions/:version/withdraw' do
    context 'when versioned layout' do
      it 'withdraws the user version' do
        put "/v1/purls/#{druid}/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:no_content)
        expect(read_version_data['versions']['1']['state']).to eq 'withdrawn'
      end
    end

    context 'when not authorized' do
      it 'returns unauthorized' do
        put "/v1/purls/#{druid}/versions/1/withdraw"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when PURL not found' do
      it 'returns not found' do
        put "/v1/purls/druid:cc123df4567/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when version not found' do
      it 'returns not found' do
        put "/v1/purls/#{druid}/versions/5/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when withdrawing head version' do
      it 'returns bad request' do
        put "/v1/purls/#{druid}/versions/2/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when PURL has been deleted' do
      let!(:purl_object) { create(:purl, :deleted, druid:) }

      it 'returns conflict' do
        put "/v1/purls/#{druid}/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe 'PUT /v1/purls/:druid/versions/:version/restore' do
    context 'when versioned layout' do
      let(:versions_data) do
        {
          versions: {
            '1' => { state: 'withdrawn', date: DateTime.now.iso8601 },
            '2' => { state: 'available', date: DateTime.now.iso8601 }
          },
          head: 2
        }
      end

      it 'withdraws the user version' do
        put "/v1/purls/#{druid}/versions/1/restore",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:no_content)
        expect(read_version_data['versions']['1']['state']).to eq 'available'
      end
    end
  end
end
