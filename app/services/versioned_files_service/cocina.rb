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
                                   file_map[file['filename']] = md5_for(file) if shelved?(file)
                                 end
                               end
                             end
                           else
                             {}
                           end
    end

    # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files
    # For example: [
    #   { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
    #   { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
    # ]
    def files_by_md5
      @files_by_md5 ||= if cocina_hash.key?('structural')
                          cocina_hash.dig('structural', 'contains').flat_map do |file_set|
                            file_set.dig('structural', 'contains').filter_map do |file|
                              { md5_for(file) => file.fetch('filename') } if shelved?(file)
                            end
                          end
                        else
                          []
                        end
    end

    private

    attr_reader :cocina_hash

    def md5_for(file)
      file['hasMessageDigests'].find { |digest| digest['type'] == 'md5' }['digest']
    end

    def shelved?(file)
      file.dig('administrative', 'shelve')
    end
  end
end
