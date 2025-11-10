class VersionedFilesService
  # Create or update a version.
  class UpdateAction
    # @param version [String] the version number
    # @param version_metadata [VersionMetadata] the metadata for the version
    # @param cocina [Cocina::Models::DRO, Cocina::Models::Collection] the cocina object
    # @param file_transfers [Hash<String, String>] a hash of filename (from cocina) to transfer UUID.
    # @param object [VersionedFilesService::Object] the object
    def initialize(version:, version_metadata:, cocina:, file_transfers:, object:)
      @version = version
      @version_metadata = version_metadata
      @cocina = cocina
      @file_transfers = file_transfers
      @object = object
    end

    # @raise [UnexpectedFileTransferError] if a file transfer is missing files or has extra files
    def call
      # Make sure the shelved files map is valid.
      validate_file_paths!
      # Make sure that all of the transfer files exist and are supposed to be shelved.
      check_file_transfers!
      # For each shelved file in the cocina object, if there is not a provided content file and a content file does not exist for the file’s md5, raise an error.
      check_content_files!

      # For each provided content file, get the md5 from the cocina object. If the content file does not already exist for that md5, then write a new content file named by the md5.
      move_content_files

      # Write the cocina to cocina path for the version (overwriting if already exists).
      write_cocina(version:, cocina: Publish::PublicCocinaGenerator.generate(cocina:))
      # Write the public xml to public xml path for the version (overwriting if already exists).
      write_public_xml(version:, public_xml:)
      # Update the version manifest.
      version_manifest.update_version(version:, version_metadata:)
      # Delete the content files that aren't referenced by any cocina version files.
      PurgeContentAction.new(object: @object).call

      ClearImageserverCache.call(druid: cocina.externalIdentifier, cocina_type: cocina.type, file_names: file_transfers.keys)

      # Copy the updated structure into the globus directory.
      update_globus_links
    end

    private

    attr_reader :version, :version_metadata, :cocina, :file_transfers

    delegate :move_content,
             :write_cocina, :write_public_xml, :version_manifest,
             :head_version,
             to: :@object

    def update_globus_links
      return unless Settings.filesystems.globus_root

      druid_id = DruidTools::Druid.new(@object.druid).id
      globus_service = VersionedFilesService::Globus.new

      return unless globus_service.globus_druid?(druid_id)

      # Remove existing Globus files for the druid
      # E.g. delete /stacks/globus/bf/070/wx/6289/
      FileUtils.rm_rf(globus_service.globus_path_for(druid_id))

      # Create new Globus links for the druid
      globus_service.link_druid(druid_id)
    end

    def check_content_files!
      shelve_file_map.each do |filename, md5|
        next if content_md5s.include?(md5)

        transfer_uuid = file_transfers[filename]

        next if transfer_uuid && transfer_path_for(transfer_uuid:).exist?

        raise Error, "Missing content file for #{filename}"
      end
    end

    def public_xml
      @public_xml ||= PublicXmlWriter.generate(cocina)
    end

    def check_file_transfers!
      file_transfers.each do |filename, transfer_uuid|
        raise BadFileTransferError, "Files in file_uploads not in cocina object" unless shelve_file_map.key?(filename)
        raise BadFileTransferError, "Transfer file for #{filename} not found" unless transfer_path_for(transfer_uuid:).exist?
      end
    end

    def move_content_files
      file_transfers.each do |filename, transfer_uuid|
        md5 = shelve_file_map[filename]
        next if content_md5s.include?(md5)

        move_content(source_path: transfer_path_for(transfer_uuid:), md5:)
        content_md5s << md5
      end
    end

    def shelve_file_map
      @shelve_file_map ||= Cocina.new(hash: cocina.to_h).shelve_file_map
    end

    def validate_file_paths!
      test_path = Pathname.new('')

      shelve_file_map.each_key do |filename|
        shelved_path = test_path / filename

        raise VersionedFilesService::Error, "File #{filename} is invalid." if shelved_path.to_s.starts_with?('../')
      end
    end

    # @return [Pathname] the path to the transfer file with the given transfer UUID
    # Note that this is the logical path; the path may not exist.
    def transfer_path_for(transfer_uuid:)
      transfer_root_path.join(transfer_uuid)
    end

    def transfer_root_path
      @transfer_root_path ||= Pathname.new(Settings.filesystems.transfer)
    end

    def content_md5s
      @content_md5s ||= @object.content_md5s
    end
  end
end
