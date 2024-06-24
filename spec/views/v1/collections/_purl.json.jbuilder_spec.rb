require 'rails_helper'

RSpec.describe 'v1/collections/_purl.json' do
  let(:purl) { create(:purl, :with_collection, catkey: 'catkey111') }

  it 'renders appropriate fields' do
    render partial: 'v1/collections/purl', locals: { purl: }
    expect(JSON.parse(rendered)).to include(
      'collections' => purl.collections.map(&:druid),
      'druid' => purl.druid,
      'object_type' => 'item',
      'catkey' => 'catkey111',
      'title' => 'Some test object'
    )
  end

  context 'when catkey is blank' do
    let(:purl) { create(:purl, :with_collection, catkey: '') }

    it 'ignores the catkey if it is blank' do
      render partial: 'v1/collections/purl', locals: { purl: }
      expect(JSON.parse(rendered)).not_to include('catkey')
    end
  end

  it 'always returns "SearchWorksPreview" for non deleted Purls' do
    render partial: 'v1/collections/purl', locals: { purl: }
    expect(rendered).to match(/SearchWorksPreview/)
  end
end
