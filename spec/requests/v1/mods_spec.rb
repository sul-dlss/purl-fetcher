require 'rails_helper'

RSpec.describe "Mods export" do
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:data) { build(:dro).to_json }

  it 'updates the purl with new data' do
    post("/v1/mods", params: data, headers:)
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <mods xmlns="http://www.loc.gov/mods/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:xlink="http://www.w3.org/1999/xlink" version="3.7" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-7.xsd">
        <titleInfo>
          <title>factory DRO title</title>
        </titleInfo>
        <location>
          <url usage="primary display">https://purl.stanford.edu/bc234fg5678</url>
        </location>
      </mods>
    XML
  end
end
