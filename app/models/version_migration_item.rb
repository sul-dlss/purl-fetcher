class VersionMigrationItem < ApplicationRecord
  validates :status, inclusion: { in: ['not_analyzed', 'queued_for_analysis', 'found_legacy', 'found_version', 'migrated'] }

  def self.create_all
    Purl.find_each do |purl|
      VersionMigrationItem.create(druid: purl.druid)
    end
  end
end
