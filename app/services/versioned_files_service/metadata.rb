class VersionedFilesService
  # Support for managing cocina.json and public xml files.
  class Metadata
    # @param paths [VersionedFilesService::Paths] the paths service
    def initialize(paths:)
      @paths = paths
    end

    # Write the cocina.json file for a version.
    # @param version [String] the version number
    # @param [Cocina] the cocina object
    # @param [Boolean] head_version true if this is the head version
    def write_cocina(version:, cocina:, head_version: false)
      FileUtils.mkdir_p(versions_path)
      cocina_path = cocina_path_for(version:)
      cocina_path.write(cocina.to_json)
      LinkSupport.link(cocina_path, head_cocina_path) if head_version
    end

    # Write the public xml file for a version.
    # @param version [String] the version number
    # @param [String] the public xml
    # @param [Boolean] head_version true if this is the head version
    def write_public_xml(version:, public_xml:, head_version: false)
      FileUtils.mkdir_p(versions_path)
      public_xml_path = public_xml_path_for(version:)
      public_xml_path.write(public_xml)
      LinkSupport.link(public_xml_path, head_public_xml_path) if head_version
    end

    # Delete the cocina.json for a version, optionally re-linking a new head cocina.json.
    # @param version [String] the version number
    # @param new_head_version [String] the new head version number, or nil if no new head
    def delete_cocina(version:, new_head_version: nil)
      cocina_path = cocina_path_for(version:)
      cocina_path.delete
      if new_head_version
        LinkSupport.link(cocina_path_for(version: new_head_version), head_cocina_path)
      elsif head_cocina_path.exist?
        head_cocina_path.delete
      end
    end

    # Delete the public xml for a version, optionally re-linking a new head public xml.
    # @param version [String] the version number
    # @param new_head_version [String] the new head version number, or nil if no new head
    def delete_public_xml(version:, new_head_version: nil)
      public_xml_path = public_xml_path_for(version:)
      public_xml_path.delete
      if new_head_version
        LinkSupport.link(public_xml_path_for(version: new_head_version), head_public_xml_path)
      elsif head_public_xml_path.exist?
        head_public_xml_path.delete
      end
    end

    delegate :cocina_path_for, :public_xml_path_for, :versions_path,
             :head_cocina_path, :head_public_xml_path, to: :@paths
  end
end
