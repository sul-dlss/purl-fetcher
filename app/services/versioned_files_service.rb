# Service for interacting with an object with a versioned files layout.
# This service also creates the external symlinks in stacks or purl filesystems.
class VersionedFilesService
  class Error < StandardError; end
  class UnknownVersionError < Error; end
  class BadFileTransferError < Error; end
  class BadRequestError < Error; end

  def initialize(druid:)
    @object = VersionedFilesService::Object.new(druid)
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
    end
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
