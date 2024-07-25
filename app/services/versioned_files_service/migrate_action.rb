class VersionedFilesService
  # Migrate an object from unversioned to versioned Stacks layout.
  class MigrateAction
    # @param object [VersionedFilesService::Object] the object
    # @param version_metadata [ VersionedFilesService::VersionsManifest::VersionMetadata] the version metadata
    def initialize(object:, version_metadata:)
      @object = object
      @version_metadata = version_metadata
    end

    def call
      # For each shelved file in the cocina object, make sure there is a content file.
      check_content_files!
      # For each shelved file, create a hardlink named by md5
      link_content_files
      # Write the cocina to cocina path for the version and create a new head cocina symlink.
      write_cocina(version: 1, cocina: cocina_hash, head_version: true)
      # Write the public xml to public xml path for the version and create a new head public xml symlink .
      write_public_xml(version: 1, public_xml:, head_version: true)
      copy_meta_json
      # Update the version manifest.
      version_manifest.update_version(version: 1, version_metadata:, head_version: true)
    end

    private

    attr_reader :version_metadata

    delegate :content_path, :content_path_for, :stacks_object_path, :meta_json_path,
             :write_cocina, :write_public_xml, :version_manifest, :druid, to: :@object

    def check_content_files!
      shelve_file_map.each_key do |filename|
        raise Error, "Content file for #{filename} not found" unless stacks_content_path_for(filename:).exist?
      end
    end

    def link_content_files
      FileUtils.mkdir_p(content_path)
      shelve_file_map.each do |filename, md5|
        LinkSupport.link(stacks_content_path_for(filename:), content_path_for(md5:))
      end
    end

    def copy_meta_json
      FileUtils.cp(purl_meta_json_path, meta_json_path) if purl_meta_json_path.exist?
    end

    def shelve_file_map
      @shelve_file_map ||= Cocina.new(hash: cocina_hash).shelve_file_map
    end

    def cocina_hash
      @cocina_hash ||= JSON.parse(purl_object_path.join('cocina.json').read)
    end

    def public_xml
      purl_object_path.join('public').read
    end

    def purl_meta_json_path
      @purl_meta_json_path ||= purl_object_path.join('meta.json')
    end

    def stacks_content_path_for(filename:)
      stacks_object_path.join(filename)
    end

    # @return [Pathname] the path to the Purl object directory
    # Note that this is the logical path; the path may not exist.
    def purl_object_path
      DruidTools::PurlDruid.new(druid, Settings.filesystems.purl_root).pathname
    end
  end
end
