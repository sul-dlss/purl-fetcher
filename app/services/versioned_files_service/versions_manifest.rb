class VersionedFilesService
  # Class for reading and writing the versions manifest.
  class VersionsManifest
    def self.read(path)
      new(path: Pathname.new(path))
    end

    # @param withdrawn [Boolean] true if the version is withdrawn
    # @param date [DateTime] the version date
    VersionMetadata = Struct.new('VersionMetadata', :version, :state, :date) do
      def withdrawn?
        state == 'withdrawn'
      end

      def permanently_withdrawn?
        state == 'permanently_withdrawn'
      end

      def available?
        state == 'available'
      end

      def as_json
        { state:, date: date&.iso8601 }.compact
      end
    end

    # @param path [Pathname] the path to the versions manifest
    def initialize(path:)
      @path = path
    end

    # Update the version manifest to include the given version.
    # @param version [Integer] the version number
    # @param version_metadata [VersionMetadata] the metadata for the version
    def update_version(version:, version_metadata:)
      manifest[:versions] ||= {}
      manifest[:versions][version] = version_metadata.as_json

      update_head_version if !version_metadata.withdrawn? && (head_version.nil? || version >= head_version)
      backfill_withdrawn_versions

      write!
    end

    # Update the version metadata to indicate that the version is withdrawn.
    # Note that this does not actually delete the version or any files.
    # @param version [Integer] the version number
    # @param withdrawn [Boolean] true if the version is withdrawn
    # @raise [UnknownVersionError] if the version is not found
    def withdraw(version:, withdrawn: true)
      check_version(version:)

      manifest[:versions][version][:state] = withdrawn ? 'withdrawn' : 'available'
      update_head_version if head_version == version

      write!
    end

    def update_head_version
      manifest[:head] = version_metadata.reject(&:withdrawn?).max_by(&:version)&.version
      manifest.delete(:head) if manifest[:head].nil?
    end

    # @return [Integer] the version number of the head version or nil
    def head_version
      manifest[:head]&.to_i
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
      date = version_data[:date].present? ? DateTime.iso8601(version_data[:date]) : nil
      VersionMetadata.new(version: version.to_i, state: version_data[:state], date:)
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
      manifest[:versions] = manifest[:versions].sort.to_h if manifest.key?(:versions)
      FileUtils.mkdir_p(path.dirname)
      path.write(manifest.to_json)
    end

    def check_version(version:)
      raise UnknownVersionError, "Version #{version} not found" unless version?(version:)
    end

    def backfill_withdrawn_versions
      return unless head_version

      (1..head_version).each do |version|
        next if version?(version:)

        manifest[:versions][version] = { state: 'permanently_withdrawn' }
      end
    end
  end
end
