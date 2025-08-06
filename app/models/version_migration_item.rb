class VersionMigrationItem < ApplicationRecord
  validates :status, inclusion: { in: ['not_analyzed', 'error', 'found_legacy', 'found_version', 'migrated'] }

  def self.create_all
    Purl.find_each do |purl|
      VersionMigrationItem.create(druid: purl.druid)
    end
  end

  def self.analyze_purls
    VersionMigrationItem.where(status: 'not_analyzed').find_each do |version_migration_item|
      stacks_path = DruidTools::PurlDruid.new(version_migration_item.druid, Settings.filesystems.stacks_root).pathname
      raise FileNotFound, stacks_path.to_s unless stacks_path.exist?

      obj = VersionedFilesService::Object.new(version_migration_item.druid)
      status = Pathname.new(obj.versions_manifest_path).exist? ? 'found_version' : 'found_legacy'
      version_migration_item.update(status:)
    rescue StandardError => e
      Honeybadger.notify(e, context: { druid: version_migration_item.druid }, tags: 'analysis')
      version_migration_item.update(status: 'error')
    end
  end
end
