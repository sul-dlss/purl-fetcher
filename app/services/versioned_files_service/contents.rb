class VersionedFilesService
  # Support for managing content files.
  class Contents
    # Suffix used for the temp file written while moving content into place.
    # The temp file lives next to the final destination so that +File.rename+
    # is atomic (same filesystem).
    TMP_SUFFIX = '.tmp'.freeze

    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:)
      @paths = paths
    end

    # @return [Array<String>] the md5s for all content files
    def content_md5s
      return [] unless content_path.exist?

      content_path.children.map { |child| child.basename.to_s }
    end

    # Moves a content file into the versioned content store.
    #
    # Safe against process termination during a cross-filesystem copy:
    #   * The source is copied to a sibling temp file (+<md5>.tmp+) inside the
    #     content directory, fsynced, then atomically renamed to its final
    #     name. A crash during the copy leaves at most the temp file; the final
    #     destination is never visible until the rename succeeds.
    #   * A leftover temp file from a prior interrupted run is removed at the
    #     start of this call.
    #   * The source is removed only after the rename has succeeded; if the
    #     process dies before the source is removed, the caller's existing
    #     cleanup of the transfer directory will reap it.
    #
    # Idempotent: returns without doing anything if the destination already
    # exists.
    #
    # @param md5 [String] the md5 of the source file; also the name of the
    #   destination.
    # @param source_path [Pathname, String] the file being moved.
    def move_content(md5:, source_path:)
      FileUtils.mkdir_p(content_path)
      dest_path = content_path_for(md5:)

      if dest_path.exist?
        Honeybadger.notify("move_content: dest_path already exists: #{dest_path}. You should check that temp path and source path have been removed!")
        return
      end

      temp_path = temp_path_for(md5:)
      # Reap a temp file left behind by a prior interrupted call.
      FileUtils.rm_f(temp_path)

      begin
        copy_with_fsync(source_path, temp_path)
        File.rename(temp_path, dest_path)
      ensure
        FileUtils.rm_f(temp_path)
      end

      FileUtils.rm_f(source_path)
    end

    def delete_content(md5:)
      content_path_for(md5:).delete
    end

    delegate :content_path_for, :content_path, to: :@paths

    private

    # Copies +source+ to +dest+ and fsyncs +dest+ before returning so the
    # bytes are durable on disk once the call returns.
    def copy_with_fsync(source, dest)
      File.open(source, 'rb') do |input|
        File.open(dest, 'wb') do |output|
          IO.copy_stream(input, output)
          output.fsync
        end
      end
    end

    def temp_path_for(md5:)
      "#{content_path_for(md5:)}#{TMP_SUFFIX}"
    end
  end
end
