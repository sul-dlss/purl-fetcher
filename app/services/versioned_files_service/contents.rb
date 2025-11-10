class VersionedFilesService
  # Support for managing content files.
  class Contents
    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:)
      @paths = paths
    end

    # @return [Array<String>] the md5s for all content files
    def content_md5s
      s3_client = S3ClientFactory.create_client

      response = s3_client.list_objects_v2(
        bucket: Settings.s3.bucket,
        prefix: content_path.to_s
      )
      response.contents.map do |object|
        object.key.delete_prefix("#{content_path}/")
      end
    end

    def move_content(md5:, source_path:)
      s3_client = S3ClientFactory.create_client
      File.open(source_path, 'rb') do |file|
        s3_client.put_object(
          bucket: Settings.s3.bucket,
          key: content_path_for(md5:).to_s,
          body: file
        )
      end
      FileUtils.rm(source_path)
    end

    def delete_content(md5:)
      s3_client = S3ClientFactory.create_client

      s3_client.delete_object(
        bucket: Settings.s3.bucket,
        key: content_path_for(md5:).to_s
      )
    end

    delegate :content_path_for, :content_path, to: :@paths
  end
end
