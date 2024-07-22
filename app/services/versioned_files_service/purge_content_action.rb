class VersionedFilesService
  # Deletes content files that aren't referenced by any cocina version files.
  class PurgeContentAction
    # @param service [VersionedFilesService] the service
    def initialize(service:)
      @service = service
    end

    def call
      (content_md5s - cocina_content_md5s).each do |md5|
        delete_content(md5:)
      end
    end

    private

    delegate :content_md5s, :delete_content, :versions, :content_path_for, :druid,
             to: :@service

    def cocina_content_md5s
      versions.map do |version|
        cocina = Cocina.for(druid:, version:)
        cocina.shelve_file_map.values
      end.flatten.uniq
    end

    def delete_content(md5:)
      content_path_for(md5:).delete
    end
  end
end
