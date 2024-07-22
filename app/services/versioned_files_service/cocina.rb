class VersionedFilesService
  # Class for Cocina that doesn't rely on Dro::Models, since no guarantee that JSON will conform with latest.
  class Cocina
    # @param [String] druid the druid
    # @param [String] version the version
    # @return [Cocina] the Cocina object
    # @raise [VersionedFilesService::Error] if the Cocina file is not found
    def self.for(druid:, version:)
      cocina_path = VersionedFilesService::Paths.new(druid:).cocina_path_for(version:)
      raise VersionedFilesService::Error, "Cocina for version #{version} not found" unless cocina_path.exist?

      new(hash: JSON.parse(cocina_path.read))
    end

    # @param [Hash] hash the cocina hash
    def initialize(hash:)
      @cocina_hash = hash.with_indifferent_access
    end

    # @return [Hash<String,String>] map of filename to md5 for shelved files
    def shelve_file_map
      @shelve_file_map ||= if cocina_hash.key?('structural')
                             {}.tap do |file_map|
                               cocina_hash.dig('structural', 'contains')&.each do |file_set|
                                 file_set.dig('structural', 'contains').each do |file|
                                   file_map[file['filename']] = md5_for(file) if file.dig('administrative', 'shelve')
                                 end
                               end
                             end
                           else
                             {}
                           end
    end

    private

    attr_reader :cocina_hash

    def md5_for(file)
      file['hasMessageDigests'].find { |digest| digest['type'] == 'md5' }['digest']
    end
  end
end
