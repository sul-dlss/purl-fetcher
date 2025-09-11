class CocinaObjectStore
  def self.find(druid)
    stacks_path = VersionedFilesService::Paths.new(druid:).head_cocina_path

    raise "No cocina.json found for #{druid} in stacks or purl paths" unless stacks_path.exist?

    data_hash = JSON.parse(File.read(stacks_path))
    Cocina::Models.build(data_hash)
  end
end
