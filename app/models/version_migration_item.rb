class VersionMigrationItem < ApplicationRecord
  validates :status, inclusion: { in: ['not_analyzed', 'error', 'found_legacy', 'found_legacy_collection', 'found_version', 'migrated'] }

  def self.create_all
    Purl.where(deleted_at: nil).find_each do |purl|
      VersionMigrationItem.create(druid: purl.druid)
    end
  end

  def self.analyze_purls
    VersionMigrationItem.where(status: 'not_analyzed').find_each do |version_migration_item|
      stacks_path = DruidTools::PurlDruid.new(version_migration_item.druid, Settings.filesystems.stacks_root).pathname

      if stacks_path.exist?
        obj = VersionedFilesService::Object.new(version_migration_item.druid)
        status = Pathname.new(obj.versions_manifest_path).exist? ? 'found_version' : 'found_legacy'
        version_migration_item.update(status:)
      else
        purl = Purl.find_by(druid: version_migration_item.druid)
        raise "File not found: #{stacks_path}" unless purl.object_type == 'collection'

        version_migration_item.update(status: 'found_legacy_collection')
      end
    rescue StandardError => e
      Honeybadger.notify(e, context: { druid: version_migration_item.druid }, tags: 'analysis')
      version_migration_item.update(status: 'error')
    end
  end
end
