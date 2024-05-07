# For a given druid, migrates files from the Purl and Stacks mounts to an OCFL structure
class OcflMigrator
  def self.migrate(...)
    new(...).migrate
  end

  # @param [String] druid
  def initialize(druid:)
    @druid = druid
  end

  def migrate
    builder.copy_recursive(stacks_druid_path)
    builder.copy_recursive(purl_druid_path)
    builder.save
  end

  private

  attr_reader :druid

  def builder
    @builder ||= OCFL::Object::DirectoryBuilder.new(object_root: ocfl_druid_path, id: druid)
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
