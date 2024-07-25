require 'rails_helper'

RSpec.describe 'Unpublish a Purl' do
  let(:druid) { 'druid:bb050dj7711' }
  let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }

  let(:legacy_stacks_path) { "#{Settings.filesystems.stacks_root}/bb/050/dj/7711/" }
  let(:legacy_purl_path) { "#{Settings.filesystems.purl_root}/bb/050/dj/7711/" }

  before do
    allow(Racecar).to receive(:produce_sync)
    FileUtils.mkdir_p legacy_stacks_path
    FileUtils.mkdir_p legacy_purl_path
  end

  after do
    FileUtils.rm_rf legacy_stacks_path
    FileUtils.rm_rf legacy_purl_path
  end

  context 'with valid authorization token' do
    context 'when the druid exists' do
      let!(:purl_object) { create(:purl, druid:) }

      context 'when versioned files is not enabled' do
        before do
          allow(Settings.features).to receive(:versioned_files).and_return(false)
          File.write("#{legacy_stacks_path}/file3.txt", 'hello world')
        end

        it 'marks the purl as deleted and removes files' do
          expect(File).to exist("#{legacy_stacks_path}/file3.txt")

          delete("/purls/#{druid}", headers:)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist("#{legacy_stacks_path}/file3.txt")
          expect(File).not_to be_symlink("#{legacy_stacks_path}/file3.txt")
        end
      end

      context 'when versioned files is enabled' do
        let(:stacks_path) { "#{Settings.filesystems.stacks_root}/bb/050/dj/7711/bb050dj7711" }
        let(:content_path) { "#{stacks_path}/content" }
        let(:file_content_path) { "#{content_path}/5b79c8570b7ef582735f912aa24ce5f2" }
        let(:legacy_file_path) { "#{legacy_stacks_path}/file3.txt" }
        let(:versions_path) { "#{stacks_path}/versions" }
        let(:cocina_version_path) { "#{versions_path}/cocina.1.json" }
        let(:cocina_head_version_path) { "#{versions_path}/cocina.json" }
        let(:xml_version_path) { "#{versions_path}/public.1.xml" }
        let(:xml_head_version_path) { "#{versions_path}/public.xml" }
        let(:versions_json_path) { "#{versions_path}/versions.json" }

        before do
          allow(Settings.features).to receive(:versioned_files).and_return(true)

          FileUtils.mkdir_p(content_path)
          File.write(file_content_path, 'hello world')
          File.link(file_content_path, legacy_file_path)

          FileUtils.mkdir_p(versions_path)
          File.write(cocina_version_path, 'hello cocina')
          File.link(cocina_version_path, cocina_head_version_path)
          File.write(xml_version_path, 'hello public xml')
          File.link(xml_version_path, xml_head_version_path)
          File.write(versions_json_path, { versions: { '1': {} }, head: "1" }.to_json)
        end

        after do
          FileUtils.rm_rf stacks_path
          FileUtils.rm_rf legacy_stacks_path
        end

        it 'marks the purl as deleted and removes files' do
          delete("/purls/#{druid}", headers:)

          expect(response).to have_http_status(:success)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist(file_content_path)
          expect(File).not_to exist(legacy_file_path)
          expect(File).not_to exist(cocina_version_path)
          expect(File).not_to exist(cocina_head_version_path)
          expect(File).not_to exist(xml_version_path)
          expect(File).not_to exist(xml_head_version_path)
        end
      end

      context 'when versioned files is enabled and version is provided' do
        let(:service) { instance_double(VersionedFilesService, delete: true) }

        before do
          allow(Settings.features).to receive(:versioned_files).and_return(true)
          allow(VersionedFilesService).to receive_messages(versioned_files?: true, new: service)
        end

        it 'invokes VersionedFilesService#delete with the version' do
          delete("/purls/#{druid}?version=2", headers:)

          expect(response).to have_http_status(:success)
          expect(VersionedFilesService).to have_received(:new).with(druid:)
          expect(service).to have_received(:delete).with(version: 2)
        end
      end

      context 'when legacy_purl is enabled' do
        before do
          allow(Settings.features).to receive(:legacy_purl).and_return(true)
          File.write("#{legacy_purl_path}/cocina.json", 'hello cocina')
          File.write("#{legacy_purl_path}/public", 'hello xml')
        end

        it 'marks the purl as deleted and removes files' do
          expect(File).to exist("#{legacy_purl_path}/cocina.json")

          delete("/purls/#{druid}", headers:)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist("#{legacy_purl_path}/cocina.json")
          expect(File).not_to be_symlink("#{legacy_purl_path}/cocina.json")
          expect(File).not_to exist("#{legacy_purl_path}/public")
          expect(File).not_to be_symlink("#{legacy_purl_path}/public")
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
