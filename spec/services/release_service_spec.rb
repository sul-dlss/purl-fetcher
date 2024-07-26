require 'rails_helper'

RSpec.describe ReleaseService do
  subject(:service) { described_class.new(purl) }

  let(:purl) do
    build(:purl)
  end

  before do
    allow(Racecar).to receive(:produce_sync)

    FileUtils.mkdir_p(purl.purl_druid_path)
  end

  after do
    FileUtils.rm_rf(purl.purl_druid_path)
  end

  describe '#release' do
    it 'writes the meta.json file' do
      service.release({ 'index' => [], 'delete' => [] })

      expect(JSON.parse(File.read("#{purl.purl_druid_path}/meta.json"))).to include(
        '$schemaVersion' => 1,
        'sitemap' => false,
        'searchworks' => false,
        'earthworks' => false
      )
    end

    context 'when the PURL has a sitemap release tag' do
      it 'writes the meta.json file' do
        service.release({ 'index' => ['PURL sitemap'], 'delete' => [] })

        expect(JSON.parse(File.read("#{purl.purl_druid_path}/meta.json"))).to include(
          'sitemap' => true
        )
      end
    end
  end
end
