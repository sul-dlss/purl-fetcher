require 'rails_helper'

RSpec.describe PurlUpdatesConsumer do
  let(:message) { instance_double(Racecar::Message, value: message_value) }
  let!(:purl_object) { create(:purl) }

  let(:message_value) do
    build(:dro, id: purl_object.druid,
                title: "The Information Paradox for Black Holes",
                collection_ids: ['druid:xb432gf1111'])
      .new(administrative: {
             hasAdminPolicy: "druid:hv992ry2431",
             releaseTags: [
               { to: 'Searchworks', release: true },
               { to: 'Earthworks', release: false }
             ]
           })
      .to_json
  end

  before do
    described_class.new.process(message)
  end

  it "updates the purl record with the provided data" do
    purl_object.reload
    expect(purl_object.title).to eq "The Information Paradox for Black Holes"
    expect(purl_object.true_targets).to eq ["Searchworks", "SearchWorksPreview", "ContentSearch"]
    expect(purl_object.false_targets).to eq ['Earthworks']
    expect(purl_object.collections.size).to eq 1
    expect(purl_object.collections.first.druid).to eq 'druid:xb432gf1111'
  end
end
