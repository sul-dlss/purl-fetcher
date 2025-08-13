# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Publish a Collection' do
  let(:bare_druid) { 'bc123df4567' }
  let(:druid) { "druid:#{bare_druid}" }

  context 'when a collection is received' do
    let(:collection) { build(:collection_with_metadata, id: druid) }
    let(:request) do
      {
        object: collection.to_h
      }.to_json
    end

    it 'does not fail' do
      put "/v1/purls/#{druid}",
          params: request,
          headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
      expect(response).to be_created
      expect(Purl.last.druid).to eq(druid)
    end

    context 'when using the legacy endpoint' do
      after do
        FileUtils.rm_rf(Settings.filesystems.stacks_root)
      end

      it 'does not fail' do
        post "/v1/resources",
             params: request,
             headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{jwt}" }
        expect(response).to be_created
        expect(Purl.last.druid).to eq(druid)
      end
    end
  end
end
