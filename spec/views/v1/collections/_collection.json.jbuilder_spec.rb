require 'rails_helper'

describe 'v1/collections/_collection.json.jbuilder' do
  it 'renders appropriate fields' do
    render partial: 'v1/collections/collection', locals: { collection: Purl.first }
    expect(JSON.parse(rendered)).to include(
      'druid' => 'druid:ee111ff2222',
      'catkey' => ''
    )
  end
  it 'always returns "SearchWorksPreview" for non deleted Purls' do
    render partial: 'v1/collections/collection', locals: { collection: Purl.where(deleted_at: nil).first }
    expect(rendered).to match(/SearchWorksPreview/)
  end
end
