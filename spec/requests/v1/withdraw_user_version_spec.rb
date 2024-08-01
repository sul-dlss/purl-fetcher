require 'rails_helper'

RSpec.describe 'Withdraw a user version' do
  let!(:purl_object) { create(:purl, druid:) } # rubocop:disable RSpec/LetSetup
  let(:druid) { 'druid:bc123df4567' }

  let(:stacks_object_path) { 'tmp/stacks/bc/123/df/4567/bc123df4567' }
  let(:versions_path) { "#{stacks_object_path}/versions" }

  let(:object) do
    VersionedFilesService::Object.new(druid)
  end

  let(:versions_data) do
    {
      versions: {
        '1' => { withdrawn: false, date: DateTime.now.iso8601 },
        '2' => { withdrawn: false, date: DateTime.now.iso8601 }
      },
      head: 2
    }
  end

  before do
    FileUtils.mkdir_p(versions_path)
    File.write("#{versions_path}/versions.json", versions_data.to_json)
  end

  after do
    FileUtils.rm_rf(stacks_object_path)
  end

  describe 'PUT /v1/purls/:druid/versions/:version/withdraw' do
    context 'when versioned layout' do
      it 'withdraws the user version' do
        put "/v1/purls/#{druid}/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:no_content)
        versions_data = JSON.parse(File.read("#{versions_path}/versions.json"))
        expect(versions_data['versions']['1']['withdrawn']).to be true
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
      let!(:purl_object) { create(:purl, :deleted, druid:) } # rubocop:disable RSpec/LetSetup

      it 'returns conflict' do
        put "/v1/purls/#{druid}/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:conflict)
      end
    end

    context 'when not versioned layout' do
      let(:druid) { 'druid:cc123df4567' }

      it 'returns bad request' do
        put "/v1/purls/#{druid}/versions/1/withdraw",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'PUT /v1/purls/:druid/versions/:version/restore' do
    context 'when versioned layout' do
      let(:versions_data) do
        {
          versions: {
            '1' => { withdrawn: true, date: DateTime.now.iso8601 },
            '2' => { withdrawn: false, date: DateTime.now.iso8601 }
          },
          head: 2
        }
      end

      it 'withdraws the user version' do
        put "/v1/purls/#{druid}/versions/1/restore",
            headers: { 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:no_content)
        versions_data = JSON.parse(File.read("#{versions_path}/versions.json"))
        expect(versions_data['versions']['1']['withdrawn']).to be false
      end
    end
  end
end
