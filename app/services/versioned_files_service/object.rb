class VersionedFilesService
  class Object
    attr_reader :druid

    # @param druid [String] the druid
    def initialize(druid)
      @druid = druid
    end

    delegate :object_path, :content_path, :versions_path, :head_cocina_path,
             :cocina_path_for, :head_public_xml_path, :public_xml_path_for,
             :versions_manifest_path, :content_path_for, :meta_json_path,
             :lockfile_path, to: :paths

    delegate :head_version, :version?, :version_metadata_for, :version_metadata,
             :withdraw, :versions, to: :version_manifest

    delegate :content_md5s, :move_content, :delete_content, to: :contents

    delegate :write_cocina, :write_public_xml,
             :delete_cocina, :delete_public_xml, to: :metadata

    # @return [Pathname] the path to the Stacks object directory
    # Note that this is the logical path; the path may not exist.
    def stacks_object_path
      DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).pathname
    end

    # @return [VersionedfilesService::VersionsManifest] the versions manifest
    def version_manifest
      @version_manifest ||= VersionsManifest.new(path: paths.versions_manifest_path)
    end

    # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files for all versions.
    # For example: [
    #   { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
    #   { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
    # ]
    def files_by_md5
      versions.flat_map { |version| Cocina.for(druid:, version:).files_by_md5 }.uniq
    end

    def purge
      raise VersionedFilesService::PurgeError, "Cannot purge object with versions - #{versions}" unless versions.empty?

      unlink_data_files
      purge_path(object_path)
    end

    private

    # @return [VersionedfilesService::Paths] the paths
    def paths
      @paths ||= Paths.new(druid:)
    end

    # @return [VersionedfilesService::Metadata] the metadata
    def metadata
      @metadata ||= Metadata.new(paths:)
    end

    # @return [VersionedfilesService::Contents] the contents
    def contents
      @contents ||= Contents.new(paths:)
    end

    def unlink_data_files
      # Delete the vesion and meta json files, and the .lock file
      versions_manifest_path.unlink if versions_manifest_path.exist?
      meta_json_path.unlink if meta_json_path.exist?
      lockfile_path.unlink if lockfile_path.exist?
    end

    # Remove the object directory and any empty parent directories
    def purge_path(path)
      path.children.each do |child|
        break unless child.directory? # Not try to remove files

        child.rmtree if child.children.empty?
      end
      return if path.children.any?

      path.rmtree
      purge_path(path.parent)
    end
  end
end
