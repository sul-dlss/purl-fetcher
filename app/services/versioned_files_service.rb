# Service for interacting with an object with a versioned files layout.
# This service also creates the external symlinks in stacks or purl filesystems.
class VersionedFilesService
  class Error < StandardError; end
  class UnknownVersionError < Error; end
  class BadFileTransferError < Error; end
  class BadRequestError < Error; end

  # Return true if the object is in the versioned_files layout.
  def self.versioned_files?(druid:)
    new(druid:).versioned_files?
  end

  def initialize(druid:)
    @object = VersionedFilesService::Object.new(druid)
  end

  # Return true if the object is in the versioned_files layout.
  def versioned_files?
    object_path.exist?
  end

  delegate :head_version, :object_path, to: :@object

  # Creates or updates a version.
  # @param version [String] the version number
  # @param version_metadata [VersionedFilesService::VersionsManifest::VersionMetadata] the metadata for the version
  # @param cocina [Cocina::Models::DRO] the cocina model
  # @param file_transfers [Hash<String, String>] a map of filenames to transfer UUIDs
  def update(version:, version_metadata:, cocina:, file_transfers: {})
    VersionedFilesService::Lock.with_lock(@object) do
      UpdateAction.new(version:, version_metadata:, cocina:, file_transfers:, object: @object).call
      StacksLinkAction.new(version:, object: @object).call
    end
  end

  # Migrate from unversioned to versioned layout.
  # @param version_metadata [VersionedFilesService::VersionsManifest::VersionMetadata] the metadata for the version
  def migrate(version_metadata:)
    MigrateAction.new(version_metadata:, object: @object).call
  end

  # Withdraw or restore a version.
  # @param version [String] the version number
  # @param withdrawn [Boolean] true to withdraw, false to restore
  def withdraw(version:, withdrawn: true)
    VersionedFilesService::Lock.with_lock(@object) do
      WithdrawAction.new(version:, withdrawn:, object: @object).call
    end
  end
end
