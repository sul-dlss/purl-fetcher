require 'rails_helper'

describe 'v1/docs/deletes.json.jbuilder' do
  before do
    assign(
      :deletes,
      Purl.where(deleted_at: Time.zone.at(0).iso8601..Time.zone.now.iso8601).page(1)
    )
  end

  it 'has pagination' do
    render
    data = JSON.parse(rendered, symbolize_names: true)

    expect(data[:deletes]).to include hash_including(druid: 'druid:ff111gg2222')
    expect(data[:pages]).to include current_page: 1,
                                    first_page?: true,
                                    last_page?: true,
                                    next_page: nil
  end
end
