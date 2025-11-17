class CocinaObjectStore
  def self.find(druid)
    object_store = ObjectStore.new(druid:)
    version = VersionedFilesService::VersionsManifest.new(object_store:).head_version
    data_hash = object_store.read_cocina(version:)
    Cocina::Models.build(data_hash)
  end
end
