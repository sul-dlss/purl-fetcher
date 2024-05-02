# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Direct upload' do
  let(:filename) { 'test.txt' }
  let(:data) { 'text' }
  let(:checksum) { OpenSSL::Digest::MD5.base64digest(data) }
  let(:byte_size) { data.length }
  let(:content_type) { 'text/plain' }
  let(:json) { JSON.dump({ blob: { filename:, byte_size:, checksum:, content_type: } }) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" } }

  context 'when uploading a file' do
    it 'returns 204' do
      post('/v1/direct_uploads', params: json, headers:)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq 'application/json'
      direct_upload = response.parsed_body

      signed_id = direct_upload['signed_id']
      expect(signed_id).to be_truthy

      direct_upload_uri = URI.parse(direct_upload['direct_upload']['url'])
      expect(direct_upload_uri.path).to start_with('/v1/disk/')

      put(direct_upload_uri.path, params: data, headers: { 'Content-Type' => content_type })

      expect(response).to have_http_status(:no_content) # Status: 204
    end
  end

  context 'when no authorization token is provided' do
    it 'returns 401' do
      post('/v1/direct_uploads', params: json, headers: headers.except('Authorization'))

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
