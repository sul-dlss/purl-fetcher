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
  let(:version) { 1 }
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
      FileUtils.rm_rf(Settings.filesystems.stacks_root)

      FileUtils.mkdir_p(transfer_dir)
      File.write(transfer_dir + 'd7e54aed-c0c4-48af-af93-bc673f079f9a', "Hello world")
      File.write(transfer_dir + '7f807e3c-4cde-4b6d-8e76-f24455316a01', "The other one")
    end

    after do
      FileUtils.rm_rf(transfer_dir)
      FileUtils.rm_rf(Settings.filesystems.stacks_root)
    end

    context 'when the object does not already exist' do
      it 'creates the resource' do
        put "/v1/purls/#{druid}",
            params: request,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf')
      end
    end

    context 'when the object already exists' do
      before do
        FileUtils.mkdir_p('tmp/stacks/bc/123/df/4567/bc123df4567/versions')
        FileUtils.mkdir('tmp/stacks/bc/123/df/4567/bc123df4567/content')
      end

      it 'creates the resource' do
        put "/v1/purls/#{druid}",
            params: request,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62')
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf')
      end

      context 'when type is image' do
        let(:dro) { build(:dro_with_metadata, type: Cocina::Models::ObjectType.image, id: druid).new(structural:, access: { view: 'world', download: 'world' }) }
        let(:file_uploads) { { 'image2.jp2' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a', 'files/image2.jp2' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }

        let(:contains) do
          [
            Cocina::Models::FileSet.new(
              externalIdentifier: 'bc123df4567_2',
              type: Cocina::Models::FileSetType.file,
              label: 'image file',
              version: 1,
              structural: Cocina::Models::FileSetStructural.new(
                contains: [
                  Cocina::Models::File.new(
                    externalIdentifier: '1234',
                    type: Cocina::Models::ObjectType.file,
                    label: 'the regular file',
                    filename: 'image2.jp2',
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
                    filename: 'files/image2.jp2',
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

        before do
          allow(ClearImageserverCache).to receive(:post_to_server).and_return(status)
        end

        context 'when response is success' do
          let(:status) do
            instance_double(HTTPX::Response, error: nil)
          end

          it 'purges cached data from the image server' do
            put "/v1/purls/#{druid}",
                params: request,
                headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
            expect(response).to be_created
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62')
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf')
            expect(ClearImageserverCache).to have_received(:post_to_server)
              .with("{\"verb\":\"PurgeItemFromCache\",\"identifier\":\"bc/123/df/4567/image2.jp2\"}")
            expect(ClearImageserverCache).to have_received(:post_to_server)
              .with("{\"verb\":\"PurgeItemFromCache\",\"identifier\":\"bc/123/df/4567/files/image2.jp2\"}")
          end
        end

        context 'when response is failure' do
          let(:status) do
            instance_double(HTTPX::ErrorResponse, error: HTTPX::HTTPError)
          end

          before do
            allow(Honeybadger).to receive(:notify)
          end

          it 'alerts honeybadger' do
            put "/v1/purls/#{druid}",
                params: request,
                headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
            expect(response).to be_created
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62')
            expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf')
            expect(ClearImageserverCache).to have_received(:post_to_server)
              .with("{\"verb\":\"PurgeItemFromCache\",\"identifier\":\"bc/123/df/4567/image2.jp2\"}")
            expect(ClearImageserverCache).to have_received(:post_to_server)
              .with("{\"verb\":\"PurgeItemFromCache\",\"identifier\":\"bc/123/df/4567/files/image2.jp2\"}")
            expect(Honeybadger).to have_received(:notify).twice
          end
        end
      end
    end

    context 'when the object is locked' do
      before do
        FileUtils.mkdir_p('tmp/stacks/bc/123/df/4567/bc123df4567/versions')

        f = File.open("tmp/stacks/bc/123/df/4567/bc123df4567/versions/.lock", File::RDWR | File::CREAT)
        f.flock(File::LOCK_EX)
      end

      it 'returns an HTTP 423 ("Locked") error' do
        put "/v1/purls/#{druid}",
            params: request,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }

        expect(response).to have_http_status(:locked)
      end
    end

    context 'when file is already in Stacks, but not found in the Cocina object' do
      before do
        FileUtils.mkdir_p('tmp/stacks/bc/123/df/4567/bc123df4567/content')
        File.write('tmp/stacks/bc/123/df/4567/bc123df4567/content/file3.txt', 'hello world')
      end

      it 'deletes the file' do
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/file3.txt')
        put "/v1/purls/#{druid}",
            params: request,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).not_to exist('tmp/stacks/bc/123/df/4567/bc123df4567/content/file3.txt')
      end
    end

    context 'when no files' do
      let(:file_uploads) { {} }
      let(:contains) { [] }

      it 'creates the cocina json file for the resource' do
        put "/v1/purls/#{druid}",
            params: request,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(File).to exist('tmp/stacks/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
      end
    end

    context 'when file listed in the file_uploads is not found in structural' do
      let(:file_uploads) { { 'xfile2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a' } }

      it 'returns 400' do
        put "/v1/purls/#{druid}",
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
end
