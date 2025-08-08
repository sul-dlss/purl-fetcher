class VersionedFilesService
  # Hardlink files in the /globus directory for the specified druids
  class Globus
    def initialize
      @globus_root = Settings.filesystems.globus_root
      @druid_list = Settings.globus.druid_list
    end

    def link_all_druids
      @druid_list.each do |druid|
        link_druid(druid)
      end
    end

    # This method can take up to 1 minute to run for druids with many files.
    # For example bf070wx6289 has 36,789 files and took 58 seconds to run linking.
    def link_druid(druid)
      object = VersionedFilesService::Object.new(druid)
      link_globus_files(object)
    end

    def globus_path_for(druid)
      DruidTools::PurlDruid.new(druid, @globus_root).pathname
    end

    def globus_druid?(druid)
      @druid_list.include?(druid)
    end

    private

    def link_globus_files(object)
      # Only link current version files
      version = object.version_manifest.head_version
      return unless version

      globus_path = globus_path_for(object.druid)
      file_details = object.file_details_by_md5_for_version(object.druid, version)

      file_details.each do |file|
        source_file_path = object.content_path_for(md5: file.md5)
        globus_file_path = globus_path / file.filename
        LinkSupport.link(source_file_path, globus_file_path)
      end
    end
  end
end
