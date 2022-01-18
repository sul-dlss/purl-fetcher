require 'rails_helper'

describe 'v1/collections/index.json' do
  before do
    assign(
      :collections,
      Kaminari.paginate_array(Purl.where(object_type: ['collection', 'collection|set'])).page(1)
    )
  end

  it 'has pagination' do
    render
    expect(rendered).to match(/pages/)
  end

  it 'always returns "SearchWorksPreview"' do
    render
    expect(rendered).to match(/SearchWorksPreview/)
  end
end
