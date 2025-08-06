require 'rails_helper'

RSpec.describe VersionMigrationItem do
  describe '.create_all' do
    before do
      Purl.create(druid: 'druid:dk120qp2074')
    end

    it 'creates a new VersionMigrationItem' do
      expect { described_class.create_all }.to change(described_class, :count).by(1)
      expect(described_class.last.status).to eq 'not_analyzed'
    end
  end

  describe '.analyze_purls' do
    let(:legacy_druid) { 'druid:bc123df4567' }
    let(:versioned_druid) { 'druid:dk120qp2074' }
    let(:not_found_druid) { 'druid:zz699qf3055' }
    let(:collection_druid) { 'druid:pw528bd2386' }

    before do
      FileUtils.mkdir_p DruidTools::PurlDruid.new(legacy_druid, Settings.filesystems.stacks_root).pathname.to_s

      path = VersionedFilesService::Paths.new(druid: versioned_druid)
      FileUtils.mkdir_p path.versions_path
      FileUtils.touch path.versions_manifest_path

      described_class.create(druid: legacy_druid, status: 'not_analyzed')
      described_class.create(druid: versioned_druid, status: 'not_analyzed')
      described_class.create(druid: not_found_druid, status: 'not_analyzed')
      described_class.create(druid: collection_druid, status: 'not_analyzed')
      Purl.create(druid: legacy_druid, object_type: 'item')
      Purl.create(druid: versioned_druid, object_type: 'item')
      Purl.create(druid: not_found_druid, object_type: 'item')
      Purl.create(druid: collection_druid, object_type: 'collection')
      described_class.analyze_purls
    end

    it 'analyzes every record' do
      expect(described_class.find_by(druid: legacy_druid).status).to eq 'found_legacy'
      expect(described_class.find_by(druid: versioned_druid).status).to eq 'found_version'
      expect(described_class.find_by(druid: not_found_druid).status).to eq 'error'
      expect(described_class.find_by(druid: collection_druid).status).to eq 'found_legacy_collection'
    end
  end
end
