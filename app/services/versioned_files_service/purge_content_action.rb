class VersionedFilesService
  # Deletes content files that aren't referenced by any cocina version files.
  class PurgeContentAction
    # @param object [VersionedFilesService] the object
    def initialize(object:)
      @object = object
    end

    def call
      (content_md5s - cocina_content_md5s).each do |md5|
        delete_content(md5:)
      end
    end

    private

    delegate :content_md5s, :delete_content, :versions, :druid,
             to: :@object

    def cocina_content_md5s
      versions.map do |version|
        cocina = Cocina.for(druid:, version:)
        cocina.shelve_file_map.values
      end.flatten.uniq
    end
  end
end
