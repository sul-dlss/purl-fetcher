class VersionedFilesService
  # Support for managing cocina.json and public xml files.
  class Metadata
    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:)
      @paths = paths
    end

    # Write the cocina.json file for a version.
    # @param version [Integer] the version number
    # @param [Cocina] the cocina object
    # @param [Boolean] head_version true if this is the head version
    def write_cocina(version:, cocina:)
      FileUtils.mkdir_p(versions_path)
      cocina_path = cocina_path_for(version:)
      cocina_path.write(cocina.to_json)
    end

    # Write the public xml file for a version.
    # @param version [Integer] the version number
    # @param [String] the public xml
    def write_public_xml(version:, public_xml:)
      FileUtils.mkdir_p(versions_path)
      public_xml_path = public_xml_path_for(version:)
      public_xml_path.write(public_xml)
    end

    # Delete the cocina.json for a version, optionally re-linking a new head cocina.json.
    # @param version [Integer] the version number
    def delete_cocina(version:)
      cocina_path = cocina_path_for(version:)
      cocina_path.delete
    end

    # Delete the public xml for a version
    # @param version [Integer] the version number
    def delete_public_xml(version:)
      public_xml_path = public_xml_path_for(version:)
      public_xml_path.delete
    end

    # Re-link a new head cocina.json.
    # @param version [Integer] the version number
    def link_cocina_head_version(version:)
      if version
        LinkSupport.link(cocina_path_for(version:), head_cocina_path)
      elsif head_cocina_path.exist?
        head_cocina_path.delete
      end
    end

    # Re-link a new head public xml.
    # @param version [Integer] the version number
    def link_public_xml_head_version(version:)
      if version
        LinkSupport.link(public_xml_path_for(version:), head_public_xml_path)
      elsif head_public_xml_path.exist?
        head_public_xml_path.delete
      end
    end

    delegate :cocina_path_for, :public_xml_path_for, :versions_path,
             :head_cocina_path, :head_public_xml_path, to: :@paths
  end
end
