require 'rails_helper'

RSpec.describe CocinaObjectStore do
  let(:druid) { 'druid:bc123df4567' }
  let!(:object) { create(:purl, druid: druid) }
  let(:purl_pathname) { 'tmp/purl_root' }
  let(:stacks_pathname) { 'tmp/stacks' }
  let(:cocina_json) { create(:public_json, purl: object).data }

  before do
    allow(Settings.filesystems).to receive_messages(
      purl_root: purl_pathname,
      stacks_root: stacks_pathname
    )
    FileUtils.rm_rf(purl_pathname)
    FileUtils.rm_rf(stacks_pathname)
  end

  after do
    FileUtils.rm_rf(purl_pathname)
    FileUtils.rm_rf(stacks_pathname)
  end

  describe '.find' do
    context 'when the cocina.json exists in the versioned stacks path' do
      before do
        # Create the file
        stacks_versions_path = Pathname.new("#{stacks_pathname}/bc/123/df/4567/bc123df4567/versions")
        FileUtils.mkdir_p(stacks_versions_path.to_s)
        File.write("#{stacks_versions_path}/cocina.json", cocina_json)
      end

      it 'returns a Cocina::Models::DROWithMetadata object' do
        result = described_class.find(druid)
        expect(result).to be_a(Cocina::Models::DROWithMetadata)
      end
    end

    context 'when the cocina.json exists in purl but not stacks path' do
      before do
        # Remove stacks path to simulate it not existing
        FileUtils.rm_rf(stacks_pathname)
        # Create the /purl cocina.json file
        purl_cocina_path = Pathname.new("#{purl_pathname}/bc/123/df/4567")
        FileUtils.mkdir_p(purl_cocina_path)
        File.write("#{purl_cocina_path}/cocina.json", cocina_json)
      end

      it 'falls back to the purl path and returns a Cocina::Models::DROWithMetadata object' do
        result = described_class.find(druid)
        expect(result).to be_a(Cocina::Models::DROWithMetadata)
      end
    end
  end

  describe '.legacy_cocina_path' do
    it 'returns the correct legacy purl cocina.json path for the druid' do
      expected_path = Pathname.new("#{purl_pathname}/bc/123/df/4567/cocina.json")
      expect(described_class.legacy_cocina_path(druid).to_s).to eq(expected_path.to_s)
    end
  end
end
