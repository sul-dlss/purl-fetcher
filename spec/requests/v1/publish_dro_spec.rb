# frozen_string_literal: true

require 'rails_helper'
require 'base64'

RSpec.describe 'Publish a DRO' do
  let(:bare_druid) { 'bc123df4567' }
  let(:druid) { "druid:#{bare_druid}" }
  let(:dro) { build(:dro_with_metadata, id: druid).new(structural:) }
  let(:request) do
    {
      object: dro.to_h,
      file_uploads:
    }.to_json
  end
  let(:file_uploads) { { 'file2.txt' => signed_id } }
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
              externalIdentifier: signed_id,
              type: Cocina::Models::ObjectType.file,
              label: 'the text file',
              filename: 'file2.txt',
              version: 1,
              hasMessageDigests: [
                { type: 'md5', digest: Base64.decode64(blob.checksum).unpack1('H*') }
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
  let(:blob) { create(:singleton_blob_with_file) }
  let(:signed_id) do
    ActiveStorage.verifier.generate(blob.id, purpose: :blob_id)
  end

  context 'when a cocina object is received' do
    it 'creates the cocina json file for the resource' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
      expect(File).to exist('tmp/stacks/bc/123/df/4567/file2.txt')
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
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/cocina.json')
      expect(File).to exist('tmp/purl_doc_cache/bc/123/df/4567/public')
    end
  end

  context 'when blob not found for file' do
    let(:signed_id) { ActiveStorage.verifier.generate('thisisinvalid', purpose: :blob_id) }

    it 'returns 500' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:server_error)
      expect(JSON.parse(response.body)['errors'][0]['title']).to eq 'Error matching uploading files to file parameters.' # rubocop:disable Rails/ResponseParsedBody
    end
  end

  context 'when invalid signed id' do
    let(:signed_id) { 'not_a_signed_id' }

    it 'returns 400' do
      post '/v1/resources',
           params: request,
           headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to have_http_status(:bad_request)
      response_json = response.parsed_body
      expect(response_json['errors'][0]['title']).to eq 'Bad request'
      expect(response_json['errors'][0]['detail']).to eq 'Invalid signed ids found'
    end
  end

  context 'when file not found in structural' do
    let(:file_uploads) { { 'xfile2.txt' => signed_id } }

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

  context 'when file is not found in the cocina object' do
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
