class VersionedFilesService
  # Support for managing cocina.json and public xml files.
  class Metadata
    # @param paths [VersionedFilesService::Paths] the paths service
    # @param object_store [ObjectStore] the object store service
    def initialize(paths:, object_store:)
      @paths = paths
      @object_store = object_store
    end

    # Write the cocina.json file for a version.
    # @param version [String] the version number
    # @param [Cocina] the cocina object
    def write_cocina(version:, cocina:)
      cocina_path = cocina_path_for(version:)
      @object_store.put(cocina_path, self.class.deep_compact_blank(cocina.to_h).to_json)
    end

    def self.deep_compact_blank(node)
      return node unless node.is_a?(Hash)

      node.each_with_object({}) do |(key, value), output|
        case value
        when Hash
          nested = deep_compact_blank(value)
          output[key] = nested unless nested.empty?
        when Array
          compacted_array = value.map { |v| deep_compact_blank(v) }.compact_blank
          output[key] = compacted_array unless compacted_array.empty?
        when TrueClass, FalseClass
          output[key] = value
        else
          output[key] = value if value.present?
        end
      end
    end

    # Write the public xml file for a version.
    # @param version [String] the version number
    # @param [String] the public xml
    def write_public_xml(version:, public_xml:)
      public_xml_path = public_xml_path_for(version:)
      @object_store.put(public_xml_path, public_xml)
    end

    delegate :cocina_path_for, :public_xml_path_for, :versions_path, to: :@paths
  end
end
