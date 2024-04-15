require 'rails_helper'

RSpec.describe V1::DocsController do
  describe '#changes' do
    it 'assigns and renders template' do
      get '/docs/changes'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:changes]).to be_an Array
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get '/docs/changes', params: { per_page: 1 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:changes, 0, :druid)).to eq 'druid:dd111ee2222'
        expect(data[:changes].count).to eq 1
      end

      it 'page' do
        get '/docs/changes', params: { per_page: 1, page: 2 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:changes, 0, :druid)).to eq 'druid:bb111cc2222'
        expect(data[:changes].count).to eq 1
      end
    end

    it 'is filterable by target' do
      get '/docs/changes', params: { target: 'SearchWorks' }
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:changes].pluck(:druid)).to contain_exactly('druid:bb111cc2222')
    end
  end

  describe '#deletes' do
    it 'assigns and renders template' do
      get '/docs/deletes'
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:deletes].count).to eq 3
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get '/docs/deletes', params: { per_page: 1 }
        data = JSON.parse(response.body, symbolize_names: true)
        expect(data.dig(:deletes, 0, :druid)).to eq 'druid:ff111gg2222'
        expect(data[:deletes].count).to eq 1
      end

      it 'page' do
        { # ordered by deleted_at
          '1' => 'druid:ff111gg2222',
          '2' => 'druid:cc111dd2222',
          '3' => 'druid:ee111ff2222'
        }.each_pair do |page, druid|
          get '/docs/deletes', params: { per_page: 1, page: }
          data = JSON.parse(response.body, symbolize_names: true)
          expect(data.dig(:deletes, 0, :druid)).to eq druid
          expect(data[:deletes].count).to eq 1
        end
      end
    end

    it 'is filterable by target' do
      get '/docs/deletes', params: { target: 'SearchWorks' }
      data = JSON.parse(response.body, symbolize_names: true)
      expect(data[:deletes].pluck(:druid)).to contain_exactly('druid:cc111dd2222')
    end
  end
end
