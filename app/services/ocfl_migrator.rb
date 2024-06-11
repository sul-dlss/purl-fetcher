# For a given druid, migrates files from the Purl and Stacks mounts to an OCFL structure
class OcflMigrator
  def self.migrate(...)
    new(...).migrate
  end

  # @param [String] druid
  def initialize(druid:, overwrite: false)
    @druid = druid
    @overwrite = overwrite
  end

  def migrate
    return if !overwrite && File.exist?(ocfl_druid_path)

    ocfl_object.copy_recursive(stacks_druid_path)
    ocfl_object.copy_recursive(purl_druid_path)
    ocfl_object.save
  end

  private

  attr_reader :druid, :overwrite

  def ocfl_object
    @ocfl_object ||= storage_root.object(druid)
  end

  def storage_root
    OCFL::StorageRoot.new(base_directory: Settings.filesystems.ocfl_root)
  end

  def purl_druid_path
    DruidTools::PurlDruid
      .new(druid, Settings.filesystems.purl_root)
      .path
  end

  def stacks_druid_path
    DruidTools::StacksDruid
      .new(druid, Settings.filesystems.stacks_root)
      .path
  end

  def ocfl_druid_path
    DruidTools::AccessDruid
      .new(druid, Settings.filesystems.ocfl_root)
      .path
  end
end
