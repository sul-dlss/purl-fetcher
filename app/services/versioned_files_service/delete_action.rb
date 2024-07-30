class VersionedFilesService
  # Deletes head version.
  class DeleteAction
    # @param version [String] the version number
    # @param object [VersionedFilesService::Object] the object
    def initialize(version:, object:)
      @version = version
      @object = object
    end

    # @raise [UnknowVersionError] if the version is not found
    # @raise [Error] if the version is not the head version
    def call
      raise VersionedFilesService::UnknowVersionError, "Version #{version} not found" unless version?(version:)

      raise VersionedFilesService::Error, "Only head version can be deleted" unless head_version == version

      new_head_version = version_manifest.previous_head_version(before: version)
      # Update the version manifest.
      version_manifest.delete_version(version:)
      # Delete the cocina version file and set the new head symlink.
      delete_cocina(version:, new_head_version:)
      # Delete the public xml version file and set the new head symlink.
      delete_public_xml(version:, new_head_version:)
      # Delete the content files that aren't referenced by any cocina version files.
      PurgeContentAction.new(object: @object).call
    end

    private

    attr_reader :version

    delegate :head_version, :delete_cocina, :delete_public_xml, :version_manifest, :version?, to: :@object
  end
end
