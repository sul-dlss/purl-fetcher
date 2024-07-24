class VersionedFilesService
  # Create or update a version.
  class UpdateAction
    # @param version [String] the version number
    # @param version_metadata [VersionMetadata] the metadata for the version
    # @param cocina [Cocina::Models::DRO, Cocina::Models::Collection] the cocina object
    # @param public_xml [String] the public xml content
    # @param file_transfers [Hash<String, String>] a hash of filename (from cocina) to transfer UUID.
    # @param service [VersionedFilesService] the service
    def initialize(version:, version_metadata:, cocina:, public_xml:, file_transfers:, service:) # rubocop:disable Metrics/ParameterLists
      @version = version
      @version_metadata = version_metadata
      @cocina = cocina
      @public_xml = public_xml
      @file_transfers = file_transfers
      @service = service
    end

    # @raise [UnexpectedFileTransferError] if a file transfer is missing files or has extra files
    def call
      # Make sure that all of the transfer files exist and are supposed to be shelved.
      check_file_transfers!
      # For each shelved file in the cocina object, if there is not a provided content file and a content file does not exist for the file’s md5, raise an error.
      check_content_files!
      # For each provided content file, get the md5 from the cocina object. If the content file does not already exist for that md5, then write a new content file named by the md5.
      move_content_files
      # Write the cocina to cocina path for the version (overwriting if already exists).
      # Create a new head cocina symlink if the version is the head version.
      write_cocina(version:, cocina:, head_version: new_head?)
      # Write the public xml to public xml path for the version (overwriting if already exists).
      # Create a new head public xml symlink if the version is the head version.
      write_public_xml(version:, public_xml:, head_version: new_head?)
      # Update the version manifest.
      version_manifest.update_version(version:, version_metadata:, head_version: new_head?)
      # Delete the content files that aren't referenced by any cocina version files.
      PurgeContentAction.new(service: @service).call
    end

    private

    attr_reader :version, :version_metadata, :cocina, :public_xml, :file_transfers

    delegate :content_md5s, :content_path, :move_content,
             :write_cocina, :write_public_xml, :version_manifest,
             :head_version?, :head_version,
             to: :@service

    def check_content_files!
      shelve_file_map.each do |filename, md5|
        next if content_md5s.include?(md5)

        transfer_uuid = file_transfers[filename]

        next if transfer_uuid && transfer_path_for(transfer_uuid:).exist?

        raise Error, "Missing content file for #{filename}"
      end
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
      end
    end

    def shelve_file_map
      @shelve_file_map ||= Cocina.new(hash: cocina.to_h).shelve_file_map
    end

    def new_head?
      if head_version?
        version.to_i > head_version.to_i
      else
        true
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
  end
end
