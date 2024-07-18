class UpdateStacksFilesService
  class BlobError < StandardError; end
  class RequestError < StandardError; end

  def self.write!(...)
    new(...).write!
  end

  def self.delete!(...)
    new(...).delete!
  end

  def initialize(cocina_object, file_uploads_map = {})
    @cocina_object = cocina_object
    @file_uploads_map = file_uploads_map
    @stacks_druid_path = DruidTools::PurlDruid.new(cocina_object.externalIdentifier, Settings.filesystems.stacks_root).path

    @content_addressed_storage = ContentAddressedStorage.new(cocina_object.externalIdentifier)
  end

  def write!
    check_files_in_structural
    shelve_files
    unshelve_removed_files
  end

  def delete!
    @cocina_filenames = []
    unshelve_removed_files
  end

  private

  attr_reader :cocina_object, :file_uploads_map, :stacks_druid_path, :content_addressed_storage

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
      if Settings.features.awfl
        md5 = md5_for_filename(filename)
        shelving_path = content_addressed_storage.mv(file_path:, md5:)
        create_link(filename, shelving_path)
      else
        shelving_path = File.join(stacks_druid_path, filename)
        FileUtils.mkdir_p(File.dirname(shelving_path))
        FileUtils.mv(file_path, shelving_path)
      end
    end
  end

  # Builds a hard link in the legacy stacks filesystem to the shelving path (in content addressable storage)
  def create_link(filename, shelving_path)
    # There should be no need for this check. However we're not seeing the file on the filesystem, so check for now.
    raise "Path doesn't exist: `#{shelving_path}'" unless File.exist?(shelving_path)

    links_path = File.join(stacks_druid_path, filename)
    FileUtils.mkdir_p(File.dirname(links_path))
    FileUtils.rm_f(links_path)
    File.link(shelving_path, links_path)
  end

  # Remove files from the Stacks directory that are not in the cocina object
  def unshelve_removed_files
    files_with_path = Dir.glob("#{stacks_druid_path}/**/*").reject { |file_with_path| File.directory?(file_with_path) }
    files_with_path.each do |file_with_path|
      file = file_with_path.delete_prefix("#{stacks_druid_path}/")
      next if cocina_filenames.include?(file)

      File.delete(file_with_path)
    end
    return unless Settings.features.awfl

    # delete from content addressable storage any file that is not in any version (currently only supporting one version)
    cocina_md5s.each do |hexdigest|
      content_addressed_storage.delete(md5: hexdigest)
    end
  end

  def cocina_md5s
    cocina_files.map do |file|
      md5_for_file(file)
    end
  end

  def md5_for_file(file)
    file.hasMessageDigests.find { |digest| digest.type == 'md5' }.digest
  end

  def cocina_files
    @cocina_files ||= cocina_object.structural.contains.flat_map do |fileset|
      fileset.structural.contains
    end
  end

  def md5_for_filename(filename)
    md5_for_file(cocina_files.find { |file| file.filename == filename })
  end

  def cocina_filenames
    @cocina_filenames ||= cocina_files.map(&:filename)
  end
end
