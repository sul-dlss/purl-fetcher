require 'rails_helper'

RSpec.describe PurlUpdatesConsumer do
  let(:message) { instance_double(Racecar::Message, value: message_value, key: 'druid:123') }
  let!(:purl_object) { create(:purl) }
  let(:title) { "The Information Paradox for Black Holes" }
  let(:message_value) do
    build(:dro, id: purl_object.druid,
                title:,
                collection_ids: ['druid:xb432gf1111'])
      .new(administrative: {
             hasAdminPolicy: "druid:hv992ry2431",
             releaseTags: [
               { to: 'Searchworks', release: true, what: 'self' },
               { to: 'Earthworks', release: false, what: 'self' }
             ]
           })
      .to_json
  end
  let(:consumer) { described_class.new }

  before do
    allow(Racecar).to receive(:produce_sync)
  end

  context 'without errors' do
    before do
      consumer.process(message)
    end

    it "updates the purl record with the provided data" do
      purl_object.reload
      expect(purl_object.title).to eq "The Information Paradox for Black Holes"
      expect(purl_object.true_targets).to eq ["Searchworks", "SearchWorksPreview", "ContentSearch"]
      expect(purl_object.false_targets).to eq ['Earthworks']
      expect(purl_object.collections.size).to eq 1
      expect(purl_object.collections.first.druid).to eq 'druid:xb432gf1111'
      expect(purl_object.public_xml.data).to eq message_value
      expect(Racecar).to have_received(:produce_sync)
        .with(value: String, key: purl_object.druid, topic: 'testing_topic')
    end
  end

  context 'with a utf8mb4 string value' do
    let(:title) { "𒀒 is an odd symbol" }

    before do
      allow(Honeybadger).to receive(:notify)
    end

    it 'logs a message' do
      expect { consumer.process(message) }.not_to raise_error
      expect(Honeybadger).to have_received(:notify)
    end
  end

  context 'with a different error' do
    before do
      allow(PurlCocinaUpdater).to receive(:new).and_return(updater)
      allow(updater).to receive(:update).and_raise(StandardError, 'broken')
      allow(Honeybadger).to receive(:notify)
    end

    let(:updater) { instance_double(PurlCocinaUpdater) }

    it 'logs a message' do
      expect { consumer.process(message) }.to raise_error('broken')
      expect(Honeybadger).to have_received(:notify)
    end
  end
end
