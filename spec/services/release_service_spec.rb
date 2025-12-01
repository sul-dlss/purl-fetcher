require 'rails_helper'

RSpec.describe ReleaseService do
  subject(:service) { described_class.new(purl) }

  let(:purl) do
    build(:purl)
  end
  let(:object_store) { ObjectStore.new(druid: purl.druid) }

  before do
    allow(Racecar).to receive(:produce_sync)
  end

  describe '#release' do
    it 'writes the meta.json file' do
      service.release({ 'index' => [], 'delete' => [] })
      expect(object_store.read_meta_json).to include({ "searchworks" => false, "earthworks" => false })

      expect(object_store.read_meta_json).to include(
        '$schemaVersion' => 1,
        'sitemap' => false,
        'searchworks' => false,
        'earthworks' => false
      )
    end

    context 'when the PURL has a sitemap release tag' do
      it 'writes the meta.json file' do
        service.release({ 'index' => ['PURL sitemap'], 'delete' => [] })

        expect(object_store.read_meta_json).to include(
          'sitemap' => true
        )
      end
    end

    context 'when the PURL has a sitemap + searchworks release tag' do
      it 'writes the meta.json file' do
        service.release({ 'index' => ['PURL sitemap', 'Searchworks'], 'delete' => [] })

        expect(object_store.read_meta_json).to include(
          'sitemap' => true,
          'searchworks' => true
        )
      end
    end
  end
end
