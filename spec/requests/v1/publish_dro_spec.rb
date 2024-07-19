# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Publish a DRO' do
  # disable because it's detecting that Pathname is a string
  # rubocop:disable Style/StringConcatenation
  let(:bare_druid) { 'bc123df4567' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:dro) { build(:dro_with_metadata, id: druid).new(structural:) }
  let(:request) do
    {
      object: dro.to_h,
      file_uploads:
    }.to_json
  end
  let(:file_uploads) { { 'file2.txt' => 'd7e54aed-c0c4-48af-af93-bc673f079f9a', 'files/file2.txt' => '7f807e3c-4cde-4b6d-8e76-f24455316a01' } }
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
              ]
            ),
            Cocina::Models::File.new(
              externalIdentifier: '1234',
              type: Cocina::Models::ObjectType.file,
              label: 'the hierarchical file',
              filename: 'files/file2.txt',
              version: 1,
              hasMessageDigests: [
                { type: 'md5', digest: '5997de4d5abb55f21f652aa61b8f3aaf' }
              ]
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
    before do
      FileUtils.rm_r(Rails.root + 'tmp/purl_doc_cache/bc') if Dir.exist?(Rails.root + 'tmp/purl_doc_cache/bc')
      transfer_dir = Rails.root + 'tmp/transfer'
      FileUtils.mkdir_p(transfer_dir)
      File.write(transfer_dir + 'd7e54aed-c0c4-48af-af93-bc673f079f9a', "Hello world")
      File.write(transfer_dir + '7f807e3c-4cde-4b6d-8e76-f24455316a01', "The other one")
    end

    it 'creates the cocina json file for the resource' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      if Settings.features.awfl_metadata
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/versions/cocina.json')
      end
      if Settings.features.awfl
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/content/3e25960a79dbc69b674cd4ec67a72c62')
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/content/5997de4d5abb55f21f652aa61b8f3aaf')
      end
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
      expect(File).to exist('tmp/stacks/bc/123/df/4567/file2.txt')
      expect(File).to exist('tmp/stacks/bc/123/df/4567/files/file2.txt')
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

    it 'creates the cocina json file for the resource' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      if Settings.features.awfl_metadata
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/versions/cocina.1.json')
        expect(File).to exist('tmp/stacks/content_addressable/bc/123/df/4567/bc123df4567/versions/cocina.json')
      end
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
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
