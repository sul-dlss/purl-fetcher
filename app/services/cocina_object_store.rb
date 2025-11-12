class CocinaObjectStore
  def self.find(druid)
    object_store = ObjectStore.new(druid:)
    stacks_path = head_cocina_path(druid, object_store)
    io = object_store.get(stacks_path)
    data_hash = JSON.parse(io.read)
    Cocina::Models.build(data_hash)
  end

  # @return [Pathname] the path to head version cocina.json.
  def self.head_cocina_path(druid, object_store)
    version = VersionedFilesService::VersionsManifest.new(object_store:).head_version
    VersionedFilesService::Paths.new(druid:).cocina_path_for(version:)
  end
end
