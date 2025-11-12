class S3Store
  # @param prefix [Pathname] The prefix to use for all object paths.
  def initialize(prefix:)
    @prefix = prefix
  end

  def get(path, response_target: nil)
    key = prefix.join(path).to_s

    return s3_client.get_object(bucket:, key:, response_target:) if response_target

    resp = s3_client.get_object(bucket:, key:)
    resp.body
  end

  def info(path)
    key = prefix.join(path).to_s

    s3_client.head_object(bucket:, key:)
  end

  def put(path, body)
    key = prefix.join(path).to_s

    s3_client.put_object(bucket:, key:, body:)
  end

  def list_objects(path)
    key_prefix = prefix.join(path).to_s

    response = s3_client.list_objects_v2(bucket:, prefix: key_prefix)
    response.contents.map do |object|
      object.key.delete_prefix("#{key_prefix}/")
    end
  end

  def delete(path)
    key = prefix.join(path).to_s

    s3_client.delete_object(bucket:, key:)
  end

  private

  attr_accessor :prefix

  def bucket
    Settings.s3.bucket
  end

  def s3_client
    @s3_client ||= S3ClientFactory.create_client
  end
end
