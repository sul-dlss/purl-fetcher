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
    def write_cocina(version:, cocina:)
      FileUtils.mkdir_p(versions_path)
      cocina_path = cocina_path_for(version:)
      cocina_path.write(cocina.to_json)
    end

    # Write the public xml file for a version.
    # @param version [String] the version number
    # @param [String] the public xml
    def write_public_xml(version:, public_xml:)
      FileUtils.mkdir_p(versions_path)
      public_xml_path = public_xml_path_for(version:)
      public_xml_path.write(public_xml)
    end

    delegate :cocina_path_for, :public_xml_path_for, :versions_path, to: :@paths
  end
end
