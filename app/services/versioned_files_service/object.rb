class VersionedFilesService
  class Object
    attr_reader :druid

    # @param druid [String] the druid
    def initialize(druid)
      @druid = druid
    end

    delegate :meta_json_path, to: :paths

    delegate :head_version, :version?, :version_metadata_for, :version_metadata,
             :withdraw, :versions, to: :version_manifest

    delegate :content_md5s, :move_content, :delete_content, to: :contents

    delegate :write_cocina, :write_public_xml, to: :metadata

    # @return [Pathname] the path to a lock file for the object
    # Note that this is the logical path; the path may not exist.
    def lockfile_path
      Pathname.new("tmp/locks/#{druid.delete_prefix('druid:')}.lock")
    end

    # @return [VersionedfilesService::VersionsManifest] the versions manifest
    def version_manifest
      @version_manifest ||= VersionsManifest.new(object_store: object_store)
    end

    # @return [Array<VersionedFilesService::Cocina::FileDetails>] array of hashes with md5 as key and filename as value for shelved files for all versions.
    # For example: [#<struct Struct::FileDetails md5="5b79c8570b7ef582735f912aa24ce5f2", filename="2542A.tiff", filesize=456>,
    #               #<struct Struct::FileDetails md5="cd5ca5c4666cfd5ce0e9dc8c83461d7a", filename="2542A.jp2", filesize=123>]
    def file_details_by_md5
      versions.flat_map { |version| file_details_by_md5_for_version(druid, version) }.uniq
    end

    def file_details_by_md5_for_version(druid, version)
      Cocina.for(druid:, version:).file_details_by_md5
    end

    def object_store
      @object_store ||= ObjectStore.new(druid:)
    end

    private

    # @return [VersionedfilesService::Metadata] the metadata
    def metadata
      @metadata ||= Metadata.new(object_store:)
    end

    # @return [VersionedfilesService::Contents] the contents
    def contents
      @contents ||= Contents.new(object_store:)
    end
  end
end
