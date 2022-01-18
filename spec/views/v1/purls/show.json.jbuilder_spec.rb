require 'rails_helper'

describe 'v1/purls/show.json' do
  before do
    assign(:purl, Purl.find(1))
  end

  it 'renders purl partial' do
    render
    expect(JSON.parse(rendered)).to include('collections' => ['druid:ff111gg2222'], 'druid' => 'druid:bb111cc2222')
  end

  it 'always returns "SearchWorksPreview"' do
    render
    expect(rendered).to match(/SearchWorksPreview/)
  end
end
