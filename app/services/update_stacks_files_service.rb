class UpdateStacksFilesService
  class RequestError < StandardError; end

  def self.write!(...)
    new(...).write!
  end

  def initialize(cocina_object, file_uploads_map = {})
    @cocina_object = cocina_object
    @file_uploads_map = file_uploads_map
    @stacks_druid_path = DruidTools::PurlDruid.new(cocina_object.externalIdentifier, Settings.filesystems.stacks_root).pathname
  end

  def write!
    check_files_in_structural
    shelve_files
    unshelve_removed_files(filenames_to_keep: cocina_filenames)
    ClearImageserverCache.call(druid: @cocina_object.externalIdentifier, cocina_type: @cocina_object.type, file_names: cocina_filenames)
  end

  private

  attr_reader :cocina_object, :file_uploads_map, :stacks_druid_path

  def inspect
    "<#{self.class}:#{object_id} id=#{cocina.externalIdentifier}>"
  end

  def check_files_in_structural
    return if file_uploads_map.keys.all? { |filename| cocina_filenames.include?(filename) }

    raise RequestError, 'Files in file_uploads not in cocina object'
  end

  # Copy the files from the staging area to the Stacks directory
  def shelve_files
    file_uploads_map.each do |filename, temp_storage_uuid|
      file_path = File.join(Settings.filesystems.transfer, temp_storage_uuid)
      shelving_path = stacks_druid_path / filename

      unless shelving_path.to_s.starts_with?(stacks_druid_path.to_s)
        Honeybadger.notify("Skipping #{filename} because it is outside the object directory")

        next
      end

      FileUtils.mkdir_p(File.dirname(shelving_path))
      FileUtils.mv(file_path, shelving_path)
    end
  end

  # Remove files from the Stacks directory that are not in the cocina object
  def unshelve_removed_files(filenames_to_keep: [])
    files_with_path = Dir.glob("#{stacks_druid_path}/**/*").reject { |file_with_path| File.directory?(file_with_path) }
    files_with_path.each do |file_with_path|
      file = file_with_path.delete_prefix("#{stacks_druid_path}/")
      next if filenames_to_keep.include?(file)

      File.delete(file_with_path)
    end
  end

  def cocina_files
    @cocina_files ||= cocina_object.structural.contains.flat_map do |fileset|
      fileset.structural.contains
    end
  end

  def cocina_filenames
    @cocina_filenames ||= cocina_files.map(&:filename)
  end
end
