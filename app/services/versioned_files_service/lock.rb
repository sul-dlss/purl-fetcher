class VersionedFilesService
  class Lock
    # Error raised when a lock cannot be acquired
    class LockError < StandardError; end

    # Lock the object for the duration of the block (e.g. while we're adding, deleting or modifying metadata and/or content).
    # @param object [VersionedFilesService::Object] the object to lock
    # @yield the block to execute while the object
    def self.with_lock(object, &)
      FileUtils.mkdir_p(object.lockfile_path.dirname)

      f = File.open(object.lockfile_path, File::RDWR | File::CREAT)

      ret = f.flock(File::LOCK_EX | File::LOCK_NB)

      raise LockError, "Could not lock #{object.lockfile_path}" unless ret

      begin
        yield
      ensure
        f.flock File::LOCK_UN
      end
    end
  end
end
