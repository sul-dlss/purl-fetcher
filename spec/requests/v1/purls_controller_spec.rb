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

  describe 'DELETE delete' do
    let(:druid) { 'druid:bb050dj7711' }
    let!(:purl_object) { create(:purl, druid:) }
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
      context 'with files stored in the legacy manner', skip: Settings.features.awfl do
        before do
          File.write("#{legacy_stacks_path}/file3.txt", 'hello world')
          File.write("#{legacy_purl_path}/cocina.json", 'hello cocina')
        end

        it 'marks the purl as deleted and removes files' do
          expect(File).to exist("#{legacy_stacks_path}/file3.txt")
          expect(File).to exist("#{legacy_purl_path}/cocina.json")

          delete("/purls/#{druid}", headers:)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist("#{legacy_stacks_path}/file3.txt")
          expect(File).not_to be_symlink("#{legacy_stacks_path}/file3.txt")
          expect(File).not_to exist("#{legacy_purl_path}/cocina.json")
          expect(File).not_to be_symlink("#{legacy_purl_path}/cocina.json")
        end
      end

      context 'with files stored in the content addressed manner', skip: !Settings.features.awfl do
        let(:stacks_path) { "#{Settings.filesystems.stacks_content_addressable}/bb/050/dj/7711/bb050dj7711" }
        let(:content_path) { "#{stacks_path}/content" }
        let(:file_content_path) { "#{content_path}/5b79c8570b7ef582735f912aa24ce5f2" }
        let(:legacy_file_path) { "#{legacy_stacks_path}/file3.txt" }
        let(:versions_path) { "#{stacks_path}/versions" }
        let(:cocina_version_path) { "#{versions_path}/cocina.1.json" }
        let(:cocina_head_version_path) { "#{versions_path}/cocina.json" }
        let(:legacy_purl_cocina_path) { "#{legacy_purl_path}/cocina.json" }
        let(:xml_version_path) { "#{versions_path}/public.1.xml" }
        let(:xml_head_version_path) { "#{versions_path}/public" }
        let(:legacy_purl_xml_path) { "#{legacy_purl_path}/public" }

        before do
          FileUtils.mkdir_p(content_path)
          File.write(file_content_path, 'hello world')
          File.symlink(file_content_path, legacy_file_path)

          FileUtils.mkdir_p(versions_path)
          File.write(cocina_version_path, 'hello cocina')
          File.symlink(cocina_version_path, cocina_head_version_path)
          File.symlink(cocina_version_path, legacy_purl_cocina_path)
          File.write(xml_version_path, 'hello public xml')
          File.symlink(xml_version_path, xml_head_version_path)
          File.symlink(xml_version_path, legacy_purl_xml_path)
        end

        after do
          FileUtils.rm_rf stacks_path
          FileUtils.rm_rf legacy_stacks_path
          FileUtils.rm_rf legacy_purl_path
        end

        it 'marks the purl as deleted and removes files' do
          delete("/purls/#{druid}", headers:)

          expect(response).to have_http_status(:success)

          expect(purl_object.reload).to have_attributes(deleted_at: (a_value > 5.seconds.ago))
          expect(Racecar).to have_received(:produce_sync)
            .with(key: purl_object.druid, topic: 'testing_topic', value: nil)
          expect(File).not_to exist(file_content_path)
          expect(File).not_to be_symlink(legacy_file_path)
          expect(File).not_to exist(cocina_version_path)
          expect(File).not_to be_symlink(cocina_head_version_path)
          expect(File).not_to be_symlink(legacy_purl_cocina_path)
          expect(File).not_to exist(xml_version_path)
          expect(File).not_to be_symlink(xml_head_version_path)
          expect(File).not_to be_symlink(legacy_purl_xml_path)
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

    context 'when no authorization token is provided' do
      it 'returns 401' do
        delete "/purls/#{druid}", headers: headers.except('Authorization')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
