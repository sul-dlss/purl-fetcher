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
    let(:metadata_only_druid) { 'druid:ws105jw7305' }

    before do
      FileUtils.mkdir_p DruidTools::PurlDruid.new(legacy_druid, Settings.filesystems.stacks_root).pathname.to_s

      version_paths = VersionedFilesService::Paths.new(druid: versioned_druid)
      FileUtils.mkdir_p version_paths.versions_path
      FileUtils.touch version_paths.versions_manifest_path

      purl_path = DruidTools::PurlDruid.new(metadata_only_druid, Settings.filesystems.purl_root).pathname
      FileUtils.mkdir_p purl_path.to_s
      File.write purl_path / 'cocina.json', '{"structural": {"contains": []}}'

      [legacy_druid, versioned_druid, not_found_druid, collection_druid, metadata_only_druid].each do |druid|
        described_class.create(druid: druid, status: 'not_analyzed')
      end
      [legacy_druid, versioned_druid, not_found_druid, metadata_only_druid].each do |druid|
        Purl.create(druid:, object_type: 'item')
      end
      Purl.create(druid: collection_druid, object_type: 'collection')

      described_class.analyze_purls
    end

    it 'analyzes every record' do
      expect(described_class.find_by(druid: legacy_druid).status).to eq 'found_legacy'
      expect(described_class.find_by(druid: versioned_druid).status).to eq 'found_version'
      expect(described_class.find_by(druid: not_found_druid).status).to eq 'error'
      expect(described_class.find_by(druid: collection_druid).status).to eq 'found_legacy_collection'
      expect(described_class.find_by(druid: metadata_only_druid).status).to eq 'found_legacy_metadata_only'
    end
  end
end
