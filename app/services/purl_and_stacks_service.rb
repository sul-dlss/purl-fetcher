# Facade around updating PURL and Stacks files.
class PurlAndStacksService
  def self.delete(purl:, version:)
    new(purl:).delete(version:)
  end

  def self.update(purl:, cocina_object:, file_uploads:, version:, version_date:)
    new(purl:).update(cocina_object:, file_uploads:, version:, version_date:)
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
    version_metadata = VersionedFilesService::VersionMetadata.new(withdrawn: false, date: version_date)
    VersionedFilesService.new(druid:).migrate(version_metadata:) if versioned_files_enabled? && !(new_object? || already_versioned_layout?)

    if versioned_files_enabled?
      VersionedFilesService.new(druid:).update(version:,
                                               version_metadata:,
                                               cocina: cocina_object,
                                               public_xml: PublicXmlWriter.generate(cocina_object),
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
    if versioned_files_enabled? && VersionedFilesService.versioned_files?(druid: purl.druid)
      begin
        VersionedFilesService.new(druid: purl.druid).delete(version:)
      rescue VersionedFilesService::UnknowVersionError
        # This shouldn't happen, but in case it does it can be ignored.
        # In theory, it could happen if delete is called multiple times and the Purl DB record is out of sync with
        # the PURL file system.
      end

    else
      UpdateStacksFilesService.delete!(purl.cocina_object)
    end
    UpdatePurlMetadataService.new(purl).delete! if legacy_purl_enabled?
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

  def already_versioned_layout?
    VersionedFilesService.versioned_files?(druid:)
  end

  def new_object?
    !DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname.exist?
  end
end
