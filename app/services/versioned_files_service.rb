# Service for interacting with an object with a versioned files layout.
# This service also creates the external symlinks in stacks or purl filesystems.
class VersionedFilesService
  class Error < StandardError; end
  class UnknowVersionError < Error; end
  class BadFileTransferError < Error; end

  # @param withdrawn [Boolean] true if the version is withdrawn
  # @param date [DateTime] the version date
  VersionMetadata = Struct.new('VersionMetadata', :version, :withdrawn, :date) do
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
  end

  attr_reader :druid

  delegate :object_path, :content_path, :versions_path, :head_cocina_path,
           :cocina_path_for, :head_public_xml_path, :public_xml_path_for,
           :versions_manifest_path, :content_path_for, to: :@paths

  delegate :head_version, :head_version?, :version?, :version_metadata_for,
           :withdraw, :versions, :version_metadata, to: :version_manifest

  delegate :content_md5s, :move_content, :delete_content, to: :contents

  delegate :write_cocina, :write_public_xml,
           :delete_cocina, :delete_public_xml, to: :metadata

  def version_manifest
    @version_manifest ||= VersionsManifest.new(path: @paths.versions_manifest_path)
  end

  def metadata
    @metadata ||= Metadata.new(paths: @paths)
  end

  def contents
    @contents ||= Contents.new(paths: @paths)
  end

  # Creates or updates a version.
  # @param version [String] the version number
  # @param version_metadata [VersionMetadata] the metadata for the version
  # @param cocina [Cocina::Models::DRO] the cocina model
  # @param file_transfers [Hash<String, String>] a map of filenames to transfer UUIDs
  def update(version:, version_metadata:, cocina:, file_transfers: {})
    UpdateAction.new(version:, version_metadata:, cocina:, file_transfers:, service: self).call
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

  # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files for all versions.
  # For example: [
  #   { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
  #   { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
  # ]
  def files_by_md5
    versions.flat_map { |version| Cocina.for(druid:, version:).files_by_md5 }.uniq
  end
end
