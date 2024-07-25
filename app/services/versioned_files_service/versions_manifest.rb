class VersionedFilesService
  # Class for reading and writing the versions manifest.
  class VersionsManifest
    def self.read(path)
      new(path: Pathname.new(path))
    end

    # @param withdrawn [Boolean] true if the version is withdrawn
    # @param date [DateTime] the version date
    VersionMetadata = Struct.new('VersionMetadata', :version, :withdrawn, :date) do
      def withdrawn?
        withdrawn
      end

      def as_json
        { withdrawn: withdrawn?, date: date.iso8601 }
      end
    end

    # @param path [Pathname] the path to the versions manifest
    def initialize(path:)
      @path = path
    end

    # Update the version manifest to include the given version.
    # @param version [Integer] the version number
    # @param version_metadata [VersionMetadata] the metadata for the version
    # @param head_version [Boolean] true if the version is the head version
    def update_version(version:, version_metadata:, head_version: false)
      manifest[:versions] ||= {}
      manifest[:versions][version] = version_metadata.as_json

      manifest[:head] = version if head_version
      write!
    end

    # Delete the given version from the version manifest.
    # @param version [Integer] the version number
    # @param new_head_version [String, nil] the new head version number, or nil if the head version should be removed
    def delete_version(version:, new_head_version: nil)
      if new_head_version
        manifest[:head] = new_head_version
      else
        manifest.delete(:head)
      end
      manifest[:versions].delete(version)
      write!
    end

    # @return [Integer] the version number of the head version
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
      manifest[:versions].key?(version)
    end

    # @return [VersionMetadata] the metadata for the given version
    # @raise [UnknownVersionError] if the version is not found
    def version_metadata_for(version:)
      check_version(version:)

      version_data = manifest[:versions][version]
      VersionMetadata.new(version: version.to_i, withdrawn: version_data[:withdrawn], date: DateTime.iso8601(version_data[:date]))
    end

    # Update the version metadata to indicate that the version is withdrawn.
    # Note that this does not actually delete the version or any files.
    # @param version [Integer] the version number
    # @param withdrawn [Boolean] true if the version is withdrawn
    # @raise [UnknownVersionError] if the version is not found
    def withdraw(version:, withdrawn: true)
      check_version(version:)

      manifest[:versions][version][:withdrawn] = withdrawn
      write!
    end

    def version_metadata
      versions.map do |version|
        version_metadata_for(version:)
      end.sort_by(&:version)
    end

    def versions
      manifest[:versions].keys
    end

    def manifest
      @manifest ||= (path.exist? ? JSON.parse(@path.read).with_indifferent_access : {}).tap do |manifest|
        manifest[:$schemaVersion] ||= 1

        # json numeric keys are converted to strings, so convert them back to integers
        manifest[:versions] ||= {}
        manifest[:versions]&.transform_keys!(&:to_i)
        manifest[:head] &&= manifest[:head].to_i
      end
    end

    private

    attr_reader :path

    def write!
      FileUtils.mkdir_p(path.dirname)
      path.write(manifest.to_json)
    end

    def check_version(version:)
      raise UnknowVersionError, "Version #{version} not found" unless version?(version:)
    end
  end
end
