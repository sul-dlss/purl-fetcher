require 'rails_helper'

RSpec.describe V1::PurlsController do
  describe 'GET index' do
    it 'looks up Purl objects using filter' do
      get '/purls'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data.dig(:purls, 0, :druid)).to eq 'druid:dd111ee2222'
    end

    describe 'is filterable' do
      it 'by object_type' do
        get '/purls', params: { object_type: 'collection' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:purls, 0, :druid)).to eq 'druid:ff111gg2222'
        expect(data[:purls].count).to eq 1
      end
    end

    describe 'uses membership scope' do
      it 'to limit non-member objects' do
        get '/purls', params: { membership: 'none' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data[:purls].count).to eq 4
      end

      it 'to limit only objects that are part of a collection' do
        get '/purls', params: { membership: 'collection' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data[:purls].count).to eq 4
      end
    end

    describe 'uses status scope' do
      it 'to limit deleted objects' do
        get '/purls', params: { status: 'deleted' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data[:purls].count).to eq 3
      end

      it 'to limit only objects that are public' do
        get '/purls', params: { status: 'public' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data[:purls].count).to eq 5
      end
    end

    describe 'uses target scope' do
      it 'to limit targets objects' do
        get '/purls', params: { target: 'SearchWorks' }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data[:purls].count).to eq 2
      end
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get '/purls', params: { per_page: 1 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:purls, 0, :druid)).to eq 'druid:dd111ee2222'
        expect(data[:purls].count).to eq 1
      end

      it 'page' do
        get '/purls', params: { per_page: 1, page: 2 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:purls, 0, :druid)).to eq 'druid:ff111gg2222'
        expect(data[:purls].count).to eq 1
      end
    end
  end

  describe 'GET show' do
    it 'looks up a Purl by its druid' do
      get '/purls/druid:dd111ee2222'
      expect(response.status).to eq 200
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:druid]).to eq 'druid:dd111ee2222'
    end

    it 'raise a record not found error (returning a 404) when the purl druid is not found' do
      expect { get '/purls/druid:bogus' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST update' do
    context 'with cocina json' do
      before do
        allow(Racecar).to receive(:produce_sync)
      end

      let(:headers) { { 'Content-Type' => 'application/json' } }
      let(:cocina_object) do
        build(:dro_with_metadata, id: druid, title: "The Information Paradox for Black Holes",
                                  collection_ids: ['druid:xb432gf1111'])
          .new(administrative: {
                 hasAdminPolicy: "druid:hv992ry2431",
                 releaseTags: [
                   { to: 'Searchworks', release: true },
                   { to: 'Earthworks', release: false }
                 ]
               })
      end
      let(:data) { cocina_object.to_json }
      let(:expected_message_value) { Cocina::Models.without_metadata(cocina_object).to_json }

      context 'with a new item' do
        let(:druid) { 'druid:zz222yy2222' }

        it 'creates a new purl entry' do
          expect do
            post "/purls/#{druid}", params: data, headers: headers
          end.to change(Purl, :count).by(1)
          expect(response).to have_http_status(:accepted)
          expect(Racecar).to have_received(:produce_sync)
            .with(key: String, topic: 'purl-update', value: expected_message_value)
        end
      end

      context 'with an existing item' do
        let(:purl_object) { create(:purl) }
        let(:druid) { purl_object.druid }

        it 'updates the purl with new data' do
          post "/purls/#{druid}", params: data, headers: headers
          expect(Racecar).to have_received(:produce_sync)
            .with(key: druid, topic: 'purl-update', value: expected_message_value)

          expect(response).to have_http_status(:accepted)
        end
      end
    end

    context 'without cocina json' do
      it 'creates a new purl entry' do
        expect do
          post '/purls/druid:ab012cd3456'
        end.to change(Purl, :count).by(1)
      end

      it 'normalizes the druid parameter' do
        expect { post '/purls/ab012cd3456' }.to change(Purl, :count).by(1)
        expect(Purl.last.druid).to eq 'druid:ab012cd3456'
      end

      context 'with an existing item' do
        let(:purl_object) { create(:purl, druid: 'druid:bb050dj7711') }

        before do
          purl_object.update(druid: 'druid:bb050dj7711')
        end

        it 'updates the purl with new data' do
          post '/purls/druid:bb050dj7711'
          expect(purl_object.reload.title).to eq "This is Pete's New Test title for this object."
        end
      end
    end
  end

  describe 'DELETE delete' do
    let(:purl_object) { create(:purl) }

    before do
      purl_object.update(druid: 'druid:bb050dj7711')
    end

    it 'marks the purl as deleted' do
      delete '/purls/bb050dj7711'
      expect(purl_object.reload).to have_attributes(deleted_at: (a_value > Time.current - 5.seconds))
    end
  end
end
