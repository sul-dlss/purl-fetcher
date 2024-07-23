class VersionedFilesService
  # Class for reading and writing the versions manifest.
  class VersionsManifest
    # @param path [Pathname] the path to the versions manifest
    def initialize(path:)
      @path = path
    end

    # Update the version manifest to include the given version.
    # @param version [String] the version number
    # @param version_metadata [VersionMetadata] the metadata for the version
    # @param head_version [Boolean] true if the version is the head version
    def update_version(version:, version_metadata:, head_version: false)
      manifest[:versions] ||= {}
      manifest[:versions][version.to_s] = { withdrawn: version_metadata.withdrawn?, date: version_metadata.date.iso8601 }

      manifest[:head] = version.to_s if head_version
      write!
    end

    # Delete the given version from the version manifest.
    # @param version [String] the version number
    # @param new_head_version [String, nil] the new head version number, or nil if the head version should be removed
    def delete_version(version:, new_head_version: nil)
      if new_head_version
        manifest[:head] = new_head_version
      else
        manifest.delete(:head)
      end
      versions_hash.delete(version.to_s)
      write!
    end

    # @return [String] the version number of the head version
    # @raise [Error] if the head version is not found
    def head_version
      return manifest[:head] if head_version?

      raise UnknowVersionError, 'Head version not found'
    end

    # @return [Boolean] true if there is a head version
    def head_version?
      manifest.key?(:head)
    end

    # @return [Boolean] true if the given version exists (i.e., found in the version manifest)
    def version?(version:)
      versions_hash.key?(version.to_s)
    end

    # @return [VersionMetadata] the metadata for the given version
    # @raise [UnknownVersionError] if the version is not found
    def version_metadata_for(version:)
      check_version(version:)

      version_data = versions_hash[version.to_s]
      VersionMetadata.new(version_data[:withdrawn], DateTime.iso8601(version_data[:date]))
    end

    # Update the version metadata to indicate that the version is withdrawn.
    # Note that this does not actually delete the version or any files.
    # @param version [String] the version number
    # @param withdrawn [Boolean] true if the version is withdrawn
    # @raise [UnknownVersionError] if the version is not found
    def withdraw(version:, withdrawn: true)
      check_version(version:)

      versions_hash[version.to_s][:withdrawn] = withdrawn
      write!
    end

    # @return [Array<String>] the list of versions
    def versions
      versions_hash.keys
    end

    private

    attr_reader :path

    def manifest
      @manifest ||= path.exist? ? JSON.parse(@path.read).with_indifferent_access : {}
    end

    def versions_hash
      manifest.fetch(:versions, {})
    end

    def write!
      FileUtils.mkdir_p(path.dirname)
      path.write(manifest.to_json)
    end

    def check_version(version:)
      raise UnknowVersionError, "Version #{version} not found" unless version?(version:)
    end
  end
end