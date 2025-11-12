class VersionedFilesService
  # Class for Cocina that doesn't rely on Dro::Models, since no guarantee that JSON will conform with latest.
  class Cocina
    FileDetails = Struct.new('FileDetails', :md5, :filename, :filesize)

    # @param [String] druid the druid
    # @param [String] version the version
    # @return [Cocina] the Cocina object
    # @raise [VersionedFilesService::Error] if the Cocina file is not found
    def self.for(druid:, version:)
      cocina_path = VersionedFilesService::Paths.new(druid:).cocina_path_for(version:)
      io = ObjectStore.new(druid:).get(cocina_path)

      new(hash: JSON.parse(io.read))
    rescue Aws::S3::Errors::NoSuchKey
      raise VersionedFilesService::Error, "Cocina for version #{version} not found"
    end

    # @param [Hash] hash the cocina hash
    def initialize(hash:)
      @cocina_hash = hash.with_indifferent_access
    end

    # @return [Hash<String,String>] map of filename to md5 for shelved files
    def shelve_file_map
      @shelve_file_map ||= shelved_files.index_by { |file| file['filename'] }.transform_values { |file| md5_for(file) }
    end

    # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files
    # For example: [#<struct Struct::FileDetails md5="5b79c8570b7ef582735f912aa24ce5f2", filename="2542A.tiff", filesize=456>,
    #               #<struct Struct::FileDetails md5="cd5ca5c4666cfd5ce0e9dc8c83461d7a", filename="2542A.jp2", filesize=123>]
    def file_details_by_md5
      @file_details_by_md5 ||= shelved_files.map do |file|
        FileDetails.new(md5: md5_for(file), filename: file.fetch('filename'), filesize: file.fetch('size'))
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

    def shelved_files
      @shelved_files ||= cocina_hash.dig('structural', 'contains')&.flat_map do |file_set|
        file_set.dig('structural', 'contains').select { |file| shelved?(file) }
      end

      @shelved_files ||= []
    end
  end
end
