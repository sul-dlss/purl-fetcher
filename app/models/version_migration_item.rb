class VersionMigrationItem < ApplicationRecord
  validates :status, inclusion: { in: ['not_analyzed', 'error', 'found_legacy', 'found_legacy_collection',
                                       'found_legacy_metadata_only', 'found_version', 'migrated'] }

  def self.create_all
    Purl.where(deleted_at: nil).find_each do |purl|
      VersionMigrationItem.create(druid: purl.druid)
    end
  end

  def self.analyze_purls(status: 'not_analyzed')
    VersionMigrationItem.where(status:).find_each do |version_migration_item|
      stacks_path = DruidTools::PurlDruid.new(version_migration_item.druid, Settings.filesystems.stacks_root).pathname

      if stacks_path.exist?
        obj = VersionedFilesService::Object.new(version_migration_item.druid)
        status = Pathname.new(obj.versions_manifest_path).exist? ? 'found_version' : 'found_legacy'
        version_migration_item.update(status:)
      else
        analyze_one_with_no_stacks(version_migration_item)
      end
    rescue StandardError => e
      Honeybadger.notify(e, context: { druid: version_migration_item.druid }, tags: 'analysis')
      version_migration_item.update(status: 'error')
    end
  end

  # Figure out what's going on when there is no stacks path. Is it a collecton or metadata only?
  def self.analyze_one_with_no_stacks(version_migration_item)
    purl = Purl.find_by(druid: version_migration_item.druid)
    if purl.object_type == 'collection'
      version_migration_item.update(status: 'found_legacy_collection')
    elsif (cocina_path = "#{purl.purl_druid_path}/cocina.json") && File.exist?(cocina_path)
      data_hash = JSON.parse(File.read(cocina_path))
      if data_hash.dig('structural', 'contains').empty?
        version_migration_item.update(status: 'found_legacy_metadata_only')
      else
        version_migration_item.update(status: 'error')
      end
    else
      raise "File not found: #{purl.purl_druid_path}"
    end
  end
end
