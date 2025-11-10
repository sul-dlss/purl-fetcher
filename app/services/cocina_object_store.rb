class CocinaObjectStore
  def self.find(druid)
    stacks_path = VersionedFilesService::Paths.new(druid:).head_cocina_path

    s3_client = S3ClientFactory.create_client
    resp = s3_client.get_object(
      bucket: Settings.s3.bucket,
      key: stacks_path.to_s
    )

    data_hash = JSON.parse(resp.body.read)
    Cocina::Models.build(data_hash)
  end
end
