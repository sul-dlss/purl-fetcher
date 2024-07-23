# Service for interacting with an object with a versioned files layout.
# This service also creates the external symlinks in stacks or purl filesystems.
class VersionedFilesService
  class Error < StandardError; end
  class UnknowVersionError < Error; end
  class BadFileTransferError < Error; end

  # @param withdrawn [Boolean] true if the version is withdrawn
  # @param date [DateTime] the version date
  VersionMetadata = Struct.new('VersionMetadata', :withdrawn, :date) do
    def withdrawn?
      withdrawn
    end
  end

  # Return true if the object is in the versioned_files layout.
  def self.versioned_files?(druid:)
    Paths.new(druid:).object_path.exist?
  end

  def initialize(druid:)
    @druid = druid
    @paths = Paths.new(druid:)
    @version_manifest = VersionsManifest.new(path: @paths.versions_manifest_path)
    @contents = Contents.new(service: self)
    @metadata = Metadata.new(service: self)
  end

  attr_reader :druid, :version_manifest

  delegate :object_path, :content_path, :versions_path, :head_cocina_path,
           :cocina_path_for, :head_public_xml_path, :public_xml_path_for,
           :versions_manifest_path, :content_path_for, to: :@paths

  delegate :head_version, :head_version?, :version?, :version_metadata_for,
           :withdraw, :versions, to: :version_manifest

  delegate :content_md5s, :move_content, :delete_content, to: :@contents

  delegate :write_cocina, :write_public_xml,
           :delete_cocina, :delete_public_xml, to: :@metadata

  # Creates or updates a version.
  # @param version [String] the version number
  # @param version_metadata [VersionMetadata] the metadata for the version
  # @param cocina [Cocina::Models::DRO] the cocina model
  # @param public_xml [String] the public xml content
  # @param file_transfers [Hash<String, String>] a map of filenames to transfer UUIDs
  def update(version:, version_metadata:, cocina:, public_xml:, file_transfers: {})
    UpdateAction.new(version:, version_metadata:, cocina:, public_xml:, file_transfers:, service: self).call
    StacksLinkAction.new(version:, service: self).call
  end

  # Deletes a version.
  # @param version [String] the version number
  def delete(version:)
    DeleteAction.new(version:, service: self).call
    StacksLinkAction.new(version: head_version? ? head_version : nil, service: self).call
  end

  # Migrate from unversioned to versioned layout.
  # @param version_metadata [VersionMetadata] the metadata for the version
  def migrate(version_metadata:)
    MigrateAction.new(version_metadata:, service: self).call
  end

  # @return [Pathname] the path to the Stacks object directory
  # Note that this is the logical path; the path may not exist.
  def stacks_object_path
    DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname
  end
end
