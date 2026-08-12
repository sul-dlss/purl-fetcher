require 'rails_helper'

RSpec.describe IndexerLogWriter do
  describe '.produce_indexer_log_message' do
    before do
      allow(Racecar).to receive(:produce_sync)
    end

    let(:purl) { create(:purl) }

    context 'when the PURL is unreleased from Searchworks' do
      before do
        purl.release_tags.create!(name: 'Searchworks', release_type: false)
      end

      it 'publishes the unrelease to the Searchworks topic' do
        described_class.produce_indexer_log_message(purl)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: purl.druid, topic: 'testing_topic_searchworks', value: purl.as_public_json.to_json)
      end
    end

    context 'when the PURL is unreleased from Earthworks' do
      before do
        purl.release_tags.create!(name: 'Earthworks', release_type: false)
      end

      it 'publishes the unrelease to the Earthworks topic' do
        described_class.produce_indexer_log_message(purl)

        expect(Racecar).to have_received(:produce_sync)
          .with(key: purl.druid, topic: 'testing_topic_earthworks', value: purl.as_public_json.to_json)
      end
    end
  end
end
