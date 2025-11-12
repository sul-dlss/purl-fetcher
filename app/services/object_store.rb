class ObjectStore
  def initialize(druid:)
    @druid = druid
  end

  def get(path, response_target: nil)
    key = object_path.join(path).to_s

    return s3_client.get_object(bucket:, key:, response_target:) if response_target

    resp = s3_client.get_object(bucket:, key:)
    resp.body
  end

  def info(path)
    key = object_path.join(path).to_s

    s3_client.head_object(bucket:, key:)
  end

  def put(path, body)
    key = object_path.join(path).to_s

    s3_client.put_object(bucket:, key:, body:)
  end

  def list_objects(path)
    prefix = object_path.join(path).to_s

    response = s3_client.list_objects_v2(bucket:, prefix:)
    response.contents.map do |object|
      object.key.delete_prefix("#{prefix}/")
    end
  end

  def delete(path)
    key = object_path.join(path).to_s

    s3_client.delete_object(bucket:, key:)
  end

  private

  def bucket
    Settings.s3.bucket
  end

  # @return [Pathname] the path to the object directory (i.e., the root directory for the object)
  # Note that this is the logical path; the path may not exist.
  def object_path
    @object_path ||= DruidTools::Druid.new(@druid, nil).pathname
  end

  def s3_client
    @s3_client ||= S3ClientFactory.create_client
  end
end
