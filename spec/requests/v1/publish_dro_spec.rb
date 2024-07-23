# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Publish a DRO' do
  # disable because it's detecting that Pathname is a string
  # rubocop:disable Style/StringConcatenation
  let(:bare_druid) { 'bc123df4567' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:dro) { build(:dro_with_metadata, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }
  let(:request) do
    {
      object: dro.to_h,
      file_uploads:,
      version:,
      version_date: version_date.iso8601
    }.to_json
  end
  let(:file_uploads) { { 'file2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a', 'files/file2.txt' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }
  let(:version) { '1' }
  let(:version_date) { DateTime.now }

  let(:contains) do
    [
      Cocina::Models::FileSet.new(
        externalIdentifier: 'bc123df4567_2',
        type: Cocina::Models::FileSetType.file,
        label: 'text file',
        version: 1,
        structural: Cocina::Models::FileSetStructural.new(
          contains: [
            Cocina::Models::File.new(
              externalIdentifier: '1234',
              type: Cocina::Models::ObjectType.file,
              label: 'the regular file',
              filename: 'file2.txt',
              version: 1,
              hasMessageDigests: [
                { type: 'md5', digest: '3e25960a79dbc69b674cd4ec67a72c62' }
              ],
              administrative: {
                publish: true,
                shelve: true
              }
            ),
            Cocina::Models::File.new(
              externalIdentifier: '1234',
              type: Cocina::Models::ObjectType.file,
              label: 'the hierarchical file',
              filename: 'files/file2.txt',
              version: 1,
              hasMessageDigests: [
                { type: 'md5', digest: '5997de4d5abb55f21f652aa61b8f3aaf' }
              ],
              administrative: {
                publish: true,
                shelve: true
              }
            )
          ]
        )
      )
    ]
  end
  let(:structural) do
    Cocina::Models::DROStructural.new(
      contains:
    )
  end

  context 'when a cocina object is received' do
    let(:transfer_dir) { Rails.root + 'tmp/transfer' }

    before do
      FileUtils.rm_rf(transfer_dir)
      FileUtils.rm_rf(Settings.filesystems.purl_root)
      FileUtils.rm_rf(Settings.filesystems.stacks_root)

      FileUtils.mkdir_p(transfer_dir)
      File.write(transfer_dir + 'd7e54aed-c0c4-48af-af93-bc673f079f9a', "Hello world")
      File.write(transfer_dir + '7f807e3c-4cde-4b6d-8e76-f24455316a01', "The other one")
    end

    after do
      FileUtils.rm_rf(transfer_dir)
      FileUtils.rm_rf(Settings.filesystems.purl_root)
      FileUtils.rm_rf(Settings.filesystems.stacks_root)
    end

    context 'when versioned files is enabled and object does not already exist' do
      before do
        allow(Settings.features).to receive(:versioned_files).and_return(true)
      end

      # rubocop:disable RSpec/ExpectActual
      it 'creates the resource' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.json')
        expect('tmp/stacks/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62').to link_to('tmp/stacks/bc/123/df/4567/file2.txt')
        expect('tmp/stacks/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf').to link_to('tmp/stacks/bc/123/df/4567/files/file2.txt')
      end
      # rubocop:enable RSpec/ExpectActual
    end

    context 'when version files is enabled' do
      let(:versioned_files_service) { instance_double(VersionedFilesService, migrate: true, update: true) }

      let(:version_metadata) { VersionedFilesService::VersionMetadata.new(withdrawn: false, date: version_date) }

      before do
        allow(Settings.features).to receive(:versioned_files).and_return(true)
        allow(VersionedFilesService).to receive(:versioned_files?).and_return(false, true)
        allow(VersionedFilesService).to receive(:new).and_return(versioned_files_service)
      end

      it 'performs a migration before updating the resource' do
        FileUtils.mkdir_p('tmp/stacks/bc/123/df/4567')

        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created

        expect(versioned_files_service).to have_received(:migrate).with(version_metadata:)
        expect(versioned_files_service).to have_received(:update).with(version:,
                                                                       version_metadata:,
                                                                       cocina: dro,
                                                                       public_xml: PublicXmlWriter.generate(dro),
                                                                       file_transfers: file_uploads)
      end
    end

    context 'when versioned files is not enabled' do
      before do
        allow(Settings.features).to receive(:versioned_files).and_return(false)
      end

      it 'creates the resource in unversioned layout' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/file2.txt')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/files/file2.txt')
        expect(File).not_to be_symlink('tmp/stacks/bc/123/df/4567/file2.txt')
        expect(File).not_to be_symlink('tmp/stacks/bc/123/df/4567/files/file2.txt')
      end
    end

    context 'when legacy purl is enabled' do
      before do
        allow(Settings.features).to receive_messages(versioned_files: true, legacy_purl: true)
      end

      it 'created the resource' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
      end
    end

    context 'when legacy purl is not enabled' do
      before do
        allow(Settings.features).to receive_messages(versioned_files: true, legacy_purl: false)
      end

      it 'creates the cocina json file for the resource' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).not_to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
        expect(File).not_to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
      end
    end

    context 'when file is already in Stacks, but not found in the Cocina object' do
      before do
        FileUtils.mkdir_p('tmp/stacks/bc/123/df/4567/')
        File.write('tmp/stacks/bc/123/df/4567/file3.txt', 'hello world')
      end

      it 'deletes the file' do
        expect(File).to exist('tmp/stacks/bc/123/df/4567/file3.txt')
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).not_to exist('tmp/stacks/bc/123/df/4567/file3.txt')
      end
    end
  end

  context 'when no files' do
    let(:file_uploads) { {} }
    let(:contains) { [] }

    context 'when versioned files is enabled' do
      before do
        allow(Settings.features).to receive(:versioned_files).and_return(true)
      end

      it 'creates the cocina json file for the resource' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.json')
      end
    end

    context 'when legacy_purl is enabled' do
      before do
        allow(Settings.features).to receive(:legacy_purl).and_return(true)
      end

      it 'creates the cocina json file for the resource' do
        post '/v1/resources',
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
        expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
      end
    end
  end

  context 'when file listed in the file_uploads is not found in structural' do
    let(:file_uploads) { { 'xfile2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a' } }

    it 'returns 400' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:bad_request)
      response_json = response.parsed_body
      expect(response_json['errors'][0]['title']).to eq 'Bad request'
      expect(response_json['errors'][0]['detail']).to eq 'Files in file_uploads not in cocina object'
    end
  end
  # rubocop:enable Style/StringConcatenation
end
