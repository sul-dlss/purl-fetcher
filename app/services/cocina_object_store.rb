class CocinaObjectStore
  def self.find(druid)
    stacks_path = VersionedFilesService::Paths.new(druid:).head_cocina_path
    purl_path = legacy_cocina_path(druid)

    path_to_use =
      if stacks_path.exist?
        stacks_path
      elsif purl_path.exist?
        purl_path
      else
        raise "No cocina.json found for #{druid} in stacks or purl paths"
      end

    data_hash = JSON.parse(File.read(path_to_use))
    Cocina::Models.build(data_hash)
  end

  # @return [Pathname] the path to the Purl object directory
  # Note that this is the logical path; the path may not exist.
  def self.legacy_cocina_path(druid)
    path = DruidTools::PurlDruid.new(druid, Settings.filesystems.purl_root).pathname
    path.join('cocina.json')
  end
end
