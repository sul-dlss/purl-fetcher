class CocinaObjectStore
  def self.find(druid)
    stacks_path = head_cocina_path(druid)

    s3_client = S3ClientFactory.create_client
    resp = s3_client.get_object(
      bucket: Settings.s3.bucket,
      key: stacks_path.to_s
    )

    data_hash = JSON.parse(resp.body.read)
    Cocina::Models.build(data_hash)
  end

  # @return [Pathname] the path to head version cocina.json.
  def self.head_cocina_path(druid)
    paths = VersionedFilesService::Paths.new(druid:)
    versions_manifest_path = paths.versions_manifest_path
    version = VersionedFilesService::VersionsManifest.new(versions_manifest_path:).head_version

    paths.cocina_path_for(version:)
  end
end
