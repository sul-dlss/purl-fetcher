require 'rails_helper'

RSpec.describe PurlUpdatesConsumer do
  let(:message) { instance_double(Racecar::Message, value: message_value) }
  let!(:purl_object) { create(:purl) }
  let(:consumer) { described_class.new }

  before do
    allow(consumer).to receive(:produce)
    allow(consumer).to receive(:deliver!)

    consumer.process(message)
  end

  context 'with a DRO' do
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

    it "updates the purl record with the provided data" do
      purl_object.reload
      expect(purl_object.title).to eq "The Information Paradox for Black Holes"
      expect(purl_object.true_targets).to eq ["Searchworks", "SearchWorksPreview", "ContentSearch"]
      expect(purl_object.false_targets).to eq ['Earthworks']
      expect(purl_object.collections.size).to eq 1
      expect(purl_object.collections.first.druid).to eq 'druid:xb432gf1111'
      expect(consumer).to have_received(:produce)
        .with(String, key: purl_object.druid, topic: 'testing_topic')
      expect(consumer).to have_received(:deliver!)
    end
  end

  context 'with a virtual object' do
    let(:message_value) do
      build(:dro, id: purl_object.druid, title: "The Information Paradox for Black Holes")
        .new(administrative: {
               hasAdminPolicy: "druid:hv992ry2431",
               releaseTags: [
                 { to: 'Searchworks', release: true },
                 { to: 'Earthworks', release: false }
               ]
             },
             structural: {
               isMemberOf: ['druid:xb432gf1111'],
               hasMemberOrders: [{
                 members: [
                   'druid:kq126jw7402',
                   'druid:cv761kr7119',
                   'druid:kn300wd1779',
                   'druid:rz617vr4473',
                   'druid:sd322dt2118',
                   'druid:hp623ch4433',
                   'druid:sq217qj5005',
                   'druid:vd823mb5658',
                   'druid:zp230ft8517',
                   'druid:xx933wk5286',
                   'druid:qf828rv2163'
                 ]
               }]
             })
        .to_json
    end

    it "updates the purl record with the provided data" do
      purl_object.reload
      expect(purl_object.title).to eq "The Information Paradox for Black Holes"
      expect(purl_object.true_targets).to eq ["Searchworks", "SearchWorksPreview", "ContentSearch"]
      expect(purl_object.false_targets).to eq ['Earthworks']
      expect(purl_object.collections.size).to eq 1
      expect(purl_object.collections.first.druid).to eq 'druid:xb432gf1111'
      expect(purl_object.virtual_object_constituents.first.has_member).to eq 'druid:kq126jw7402'
      expect(purl_object.virtual_object_constituents.size).to eq 11
      expect(consumer).to have_received(:produce)
        .with(String, key: purl_object.druid, topic: 'testing_topic')
      expect(consumer).to have_received(:deliver!)
    end
  end
end
