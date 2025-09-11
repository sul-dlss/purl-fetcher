require 'rails_helper'

RSpec.describe ReleaseService do
  subject(:service) { described_class.new(purl) }

  let(:paths) { VersionedFilesService::Paths.new(druid: purl.druid) }

  let(:purl) do
    build(:purl)
  end

  before do
    allow(Racecar).to receive(:produce_sync)
    FileUtils.mkdir_p(paths.versions_path)
  end

  after do
    FileUtils.rm_rf(paths.versions_path)
  end

  describe '#release' do
    it 'writes the meta.json file' do
      service.release({ 'index' => [], 'delete' => [] })

      expect(JSON.parse(File.read(paths.meta_json_path))).to include(
        '$schemaVersion' => 1,
        'sitemap' => false,
        'searchworks' => false,
        'earthworks' => false
      )
    end

    context 'when the PURL has a sitemap release tag' do
      it 'writes the meta.json file' do
        service.release({ 'index' => ['PURL sitemap'], 'delete' => [] })

        expect(JSON.parse(File.read(paths.meta_json_path))).to include(
          'sitemap' => true
        )
      end
    end

    context 'when the PURL has a sitemap + searchworks release tag' do
      it 'writes the meta.json file' do
        service.release({ 'index' => ['PURL sitemap', 'Searchworks'], 'delete' => [] })

        expect(JSON.parse(File.read(paths.meta_json_path))).to include(
          'sitemap' => true,
          'searchworks' => true
        )
      end
    end
  end
end
