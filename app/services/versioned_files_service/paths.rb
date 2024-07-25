class VersionedFilesService
  # Support for paths within a versioned layout.
  class Paths
    # @param druid [String] the druid
    def initialize(druid:)
      @druid = druid
    end

    # @return [Pathname] the path to the object directory (i.e., the root directory for the object)
    # Note that this is the logical path; the path may not exist.
    def object_path
      @object_path ||= DruidTools::Druid.new(druid, Settings.filesystems.stacks_root).pathname
    end

    # @return [Pathname] the path to the content directory
    # Note that this is the logical path; the path may not exist.
    def content_path
      @content_path ||= object_path.join('content')
    end

    # @return [Pathname] the path to the metadata directory
    # Note that this is the logical path; the path may not exist.
    def versions_path
      @versions_path ||= object_path.join('versions')
    end

    # @return [Pathname] the path to head cocina.json. This may be a symlink.
    # Note that this is the logical path; the path may not exist.
    def head_cocina_path
      @head_cocina_path ||= versions_path.join('cocina.json')
    end

    # @return [Pathname] the path to cocina.json for the given version.
    # Note that this is the logical path; the path may not exist.
    def cocina_path_for(version:)
      versions_path.join("cocina.#{version}.json")
    end

    # @return [Pathname] the path to head public xml file. This may be a symlink.
    # Note that this is the logical path; the path may not exist.
    def head_public_xml_path
      @head_public_xml_path ||= versions_path.join('public.xml')
    end

    # @return [Pathname] the path to public xml file for the given version.
    # Note that this is the logical path; the path may not exist.
    def public_xml_path_for(version:)
      versions_path.join("public.#{version}.xml")
    end

    # @return [Pathname] the path to versions.json
    # Note that this is the logical path; the path may not exist.
    def versions_manifest_path
      @versions_manifest_path ||= versions_path.join('versions.json')
    end

    # @return [Pathname] the path to meta.json
    # Note that this is the logical path; the path may not exist.
    def meta_json_path
      @meta_json_path ||= versions_path.join('meta.json')
    end

    # @return [Pathname] the path to the content file with the given md5
    # Note that this is the logical path; the path may not exist.
    def content_path_for(md5:)
      content_path.join(md5)
    end

    private

    attr_reader :druid
  end
end
