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
end
