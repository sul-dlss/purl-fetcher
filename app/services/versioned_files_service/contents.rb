class VersionedFilesService
  # Support for managing content files.
  class Contents
    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:, object_store:)
      @paths = paths
      @object_store = object_store
    end

    # @return [Array<String>] the md5s for all content files
    def content_md5s
      @object_store.list_objects(content_path)
    end

    def move_content(md5:, source_path:)
      File.open(source_path, 'rb') do |file|
        @object_store.put(content_path_for(md5:), file)
      end
      FileUtils.rm(source_path)
    end

    def delete_content(md5:)
      @object_store.delete(content_path_for(md5:))
    end

    delegate :content_path_for, :content_path, to: :@paths
  end
end
