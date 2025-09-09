# Facade around updating PURL and Stacks files.
class PurlAndStacksService
  def self.update(purl:, cocina_object:, file_uploads:, version:, version_date:)
    new(purl:).update(cocina_object:, file_uploads:, version:, version_date:)
  end

  def self.withdraw(purl:, version:, withdrawn: true)
    new(purl:).withdraw(version:, withdrawn:)
  end

  # @param purl [Purl] the PURL model object.
  def initialize(purl:)
    @purl = purl
  end

  # Update the PURL and Stacks files.
  # @param cocina_object [Cocina::Models::DRO,Cocina::Models::Collection] the Cocina data object
  # @param file_uploads [Hash<String,String>] map of cocina filenames to staging filenames (UUIDs)
  # @param version [String] the version number
  # @param version_date [DateTime] the version date
  def update(cocina_object:, file_uploads:, version:, version_date:)
    version_metadata = VersionedFilesService::VersionsManifest::VersionMetadata.new(version: version.to_i, state: 'available', date: version_date)

    versioned_files_service.update(version:,
                                   version_metadata:,
                                   cocina: cocina_object,
                                   file_transfers: file_uploads)
  end

  # Withdraw or restore a version.
  # @param version [String] the version number
  # @param withdrawn [Boolean] true to withdraw, false to restore
  def withdraw(version:, withdrawn: true)
    versioned_files_service.withdraw(version:, withdrawn:)
  end

  private

  attr_reader :purl

  delegate :druid, to: :purl

  def versioned_files_service
    @versioned_files_service ||= VersionedFilesService.new(druid:)
  end
end
