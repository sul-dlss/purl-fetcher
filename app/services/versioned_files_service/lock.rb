class VersionedFilesService
  class Lock
    # Lock the object for the duration of the block (e.g. while we're adding, deleting or modifying metadata and/or content).
    # @param object [VersionedFilesService::Object] the object to lock
    # @yield the block to execute while the object
    def self.with_lock(object, &)
      FileUtils.mkdir_p(object.lockfile_path.dirname)

      f = File.open(object.lockfile_path, File::RDWR | File::CREAT)
      f.flock File::LOCK_EX

      begin
        yield
      ensure
        f.flock File::LOCK_UN
      end
    end
  end
end
