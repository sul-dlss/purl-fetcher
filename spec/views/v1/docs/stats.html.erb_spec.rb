require 'rails_helper'

describe 'v1/docs/stats' do
  before do
    assign(
      :metrics,
      Statistics.new
    )
  end

  it 'renders' do
    expect { render }.not_to raise_error
  end
end
