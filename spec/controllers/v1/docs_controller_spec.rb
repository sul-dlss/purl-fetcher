require 'rails_helper'

RSpec.describe V1::DocsController do
  describe '#changes' do
    it 'assigns and renders template' do
      get :changes, format: :json
      expect(assigns(:changes)).to be_an ActiveRecord::Relation
      expect(response).to render_template('changes')
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get :changes, params: { per_page: 1 }, format: :json
        expect(assigns(:changes).first.druid).to eq 'druid:dd111ee2222'
        expect(assigns(:changes).count).to eq 1
      end

      it 'page' do
        get :changes, params: { per_page: 1, page: 2 }, format: :json
        expect(assigns(:changes).first.druid).to eq 'druid:bb111cc2222'
        expect(assigns(:changes).count).to eq 1
      end
    end

    it 'is filterable by target' do
      get :changes, params: { target: 'SearchWorks' }, format: :json
      expect(assigns(:changes).map(&:druid)).to contain_exactly('druid:bb111cc2222')
    end
  end

  describe '#deletes' do
    it 'assigns and renders template' do
      get :deletes, format: :json
      expect(assigns(:deletes)).to be_an ActiveRecord::Relation
      expect(response).to render_template('deletes')
    end

    describe 'pagination parameters' do
      it 'per_page' do
        get :deletes, params: { per_page: 1 }, format: :json
        expect(assigns(:deletes).first.druid).to eq 'druid:ff111gg2222'
        expect(assigns(:deletes).count).to eq 1
      end

      it 'page' do
        { # ordered by deleted_at
          '1' => 'druid:ff111gg2222',
          '2' => 'druid:cc111dd2222',
          '3' => 'druid:ee111ff2222'
        }.each_pair do |page, druid|
          get :deletes, params: { per_page: 1, page: page }, format: :json
          expect(assigns(:deletes).first.druid).to eq druid
          expect(assigns(:deletes).count).to eq 1
        end
      end
    end

    it 'is filterable by target' do
      get :deletes, params: { target: 'SearchWorks' }, format: :json
      expect(assigns(:deletes).map(&:druid)).to contain_exactly('druid:cc111dd2222')
    end
  end
end
