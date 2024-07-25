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
      # set the new head symlink.
      link_cocina_head_version(version: new_head_version)
      # set the new head symlink.
      link_public_xml_head_version(version: new_head_version)
      # Update the version manifest.
      version_manifest.delete_version(version:)
      # Delete the cocina version file
      delete_cocina(version:)
      # Delete the public xml version file
      delete_public_xml(version:)
      # Delete the content files that aren't referenced by any cocina version files.
      PurgeContentAction.new(object: @object).call
    end

    private

    attr_reader :version

    delegate :head_version, :delete_cocina, :delete_public_xml, :version_manifest, :version?, :link_cocina_head_version, :link_public_xml_head_version, to: :@object
  end
end
