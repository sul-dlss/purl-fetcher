class VersionedFilesService
  # Support for managing content files.
  class Contents
    # @param object_store [ObjectStore] the object store service
    def initialize(object_store:)
      @object_store = object_store
    end

    def move_content(md5:, source_path:)
      File.open(source_path, 'rb') do |file|
        @object_store.write_content(md5:, file:)
      end
      FileUtils.rm(source_path)
    end

    delegate :delete_content, :content_md5s, to: :@object_store
  end
end
