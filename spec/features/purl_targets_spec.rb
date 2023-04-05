require 'rails_helper'

describe 'Purl targets', integration: true, type: :request do
  it 'true targets are not available on deleted documents' do
    get purl_path 'druid:ee111ff2222'
    parsed_response = JSON.parse(response.body)
    expect(parsed_response).not_to include 'true_targets'
  end
end
