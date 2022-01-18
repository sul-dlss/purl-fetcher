require 'rails_helper'

describe 'v1/collections/show.json' do
  before do
    assign(:collection, Purl.find(5))
  end

  it 'renders purl partial' do
    render
    expect(JSON.parse(rendered)).to include('druid' => 'druid:ff111gg2222')
  end
end
