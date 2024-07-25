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
    end
  end
end
