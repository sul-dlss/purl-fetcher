class VersionedFilesService
  class LinkSupport
    # Create a hard link from source to dest.
    # @param [Pathname] source_path
    # @param [Pathname] dest_path
    def self.link(source_path, dest_path)
      return if link?(source_path, dest_path)

      dest_path.delete if dest_path.exist?
      FileUtils.mkdir_p(dest_path.dirname)
      File.link(source_path, dest_path)
    end

    # @param [Pathname] path1
    # @param [Pathname] path2
    # @return [Boolean] true if both paths link to the same file
    def self.link?(path1, path2)
      path1.exist? && path2.exist? && path1.stat.ino == path2.stat.ino
    end
  end
end
