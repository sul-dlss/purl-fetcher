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
        let(:stacks_path) { "#{Settings.filesystems.stacks_root}/bb/050/dj/7711/bb050dj7711" }
        let(:content_path) { "#{stacks_path}/content" }
        let(:file_content_path) { "#{content_path}/5b79c8570b7ef582735f912aa24ce5f2" }
        let(:versions_path) { "#{stacks_path}/versions" }
        let(:cocina_version_path) { "#{versions_path}/cocina.1.json" }
        let(:xml_version_path) { "#{versions_path}/public.1.xml" }
        let(:versions_json_path) { "#{versions_path}/versions.json" }

        before do
          FileUtils.mkdir_p(content_path)
          File.write(file_content_path, 'hello world')

          FileUtils.mkdir_p(versions_path)
          File.write(cocina_version_path, 'hello cocina')
          File.write(xml_version_path, 'hello public xml')
          File.write(versions_json_path, { versions: { '1': { date: '2024' } }, head: "1" }.to_json)
        end

        after do
          FileUtils.rm_rf stacks_path
        end

        it 'marks the purl as deleted and removes files' do
          delete("/purls/#{druid}", headers:)

          expect(response).to have_http_status(:success)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist(file_content_path)
          expect(File).not_to exist(cocina_version_path)
          expect(File).not_to exist(xml_version_path)
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
