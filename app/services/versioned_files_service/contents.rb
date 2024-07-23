class VersionedFilesService
  # Support for managing content files.
  class Contents
    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:)
      @paths = paths
    end

    # @return [Array<String>] the md5s for all content files
    def content_md5s
      return [] unless content_path.exist?

      content_path.children.map { |child| child.basename.to_s }
    end

    def move_content(md5:, source_path:)
      FileUtils.mkdir_p(content_path)
      FileUtils.mv(source_path, content_path_for(md5:))
    end

    def delete_content(md5:)
      content_path_for(md5:).delete
    end

    delegate :content_path_for, :content_path, to: :@paths
  end
end
