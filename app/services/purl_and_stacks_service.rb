# Facade around updating PURL and Stacks files.
class PurlAndStacksService
  def self.delete(purl:, version:)
    new(purl:).delete(version:)
  end

  def self.update(purl:, cocina_object:, file_uploads:, version:, version_date:, must_version:) # rubocop:disable Metrics/ParameterLists
    new(purl:).update(cocina_object:, file_uploads:, version:, version_date:, must_version:)
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
  # @param must_version [Boolean] true if the versioned layout is required
  def update(cocina_object:, file_uploads:, version:, version_date:, must_version:)
    if use_versioned_layout? || must_version
      version_metadata = VersionedFilesService::VersionsManifest::VersionMetadata.new(version: version.to_i, state: 'available', date: version_date)
      versioned_files_service.migrate(version_metadata:) unless already_versioned_layout? || new_object?

      versioned_files_service.update(version:,
                                     version_metadata:,
                                     cocina: cocina_object,
                                     file_transfers: file_uploads)
      # Writes to purl. In the future when PURL Application can handle versioned layout, this will be removed.
      UpdatePurlMetadataService.new(purl).write! if legacy_purl_enabled?

    else
      # Writes to stacks with unversioned layout.
      UpdateStacksFilesService.write!(cocina_object, file_uploads) unless cocina_object.collection?
      UpdatePurlMetadataService.new(purl).write!
    end
  end

  # Delete the PURL and Stacks files.
  # @param version [String] the version number
  def delete(version:)
    if versioned_files_enabled? && already_versioned_layout?
      begin
        versioned_files_service.delete(version:)
      rescue VersionedFilesService::UnknownVersionError
        # This shouldn't happen, but in case it does it can be ignored.
        # In theory, it could happen if delete is called multiple times and the Purl DB record is out of sync with
        # the PURL file system.
      end

    else
      UpdateStacksFilesService.delete!(purl.cocina_object)
    end
    UpdatePurlMetadataService.new(purl).delete! if legacy_purl_enabled?
  end

  # Withdraw or restore a version.
  # @param version [String] the version number
  # @param withdrawn [Boolean] true to withdraw, false to restore
  def withdraw(version:, withdrawn: true)
    # unversioned is an implicit version 1, which cannot be withdrawn.
    raise VersionedFilesService::BadRequestError, 'Cannot withdraw head version' unless already_versioned_layout?

    versioned_files_service.withdraw(version:, withdrawn:)
  end

  private

  attr_reader :purl

  delegate :druid, to: :purl

  def versioned_files_enabled?
    Settings.features.versioned_files
  end

  def legacy_purl_enabled?
    Settings.features.legacy_purl
  end

  def use_versioned_layout?
    return false unless versioned_files_enabled?

    # Use versioned layout (1) if the object is already using the versioned layout; (2) if the object is new; or
    # (3) if the object is using the unversioned layout, but DSA indicates that the object is versioned.
    # 3 may be the case for existing H2 objects, as they were previously unversioned but versions are being added.

    # TODO: Support DSA indicating if an object is versioned.

    # Is it already in versioned layout?
    return true if already_versioned_layout?

    # Is it a new object?
    return true if new_object?

    false
  end

  def new_object?
    # Stacks directory (e.g., /stacks/bc/123/df/4567) does nto exist.
    !DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname.exist?
  end

  def versioned_files_service
    @versioned_files_service ||= VersionedFilesService.new(druid:)
  end

  def already_versioned_layout?
    versioned_files_service.versioned_files?
  end
end
