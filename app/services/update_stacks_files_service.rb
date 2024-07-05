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
    awfl_directory = DruidTools::Druid.new(cocina_object.externalIdentifier, Settings.filesystems.stacks_content_addressable).path
    @content_addressable_path = "#{awfl_directory}/content"
  end

  def write!
    check_files_in_structural
    check_signed_ids
    shelve_files
    unshelve_removed_files
  end

  def delete!
    @cocina_filenames = []
    unshelve_removed_files
  end

  private

  attr_reader :cocina_object, :file_uploads_map, :stacks_druid_path, :content_addressable_path

  def check_files_in_structural
    return if file_uploads_map.keys.all? { |filename| cocina_filenames.include?(filename) }

    raise RequestError, 'Files in file_uploads not in cocina object'
  end

  def check_signed_ids
    return if file_uploads_map.values.all? { |signed_id| ActiveStorage.verifier.valid_message?(signed_id) }

    raise RequestError, "Invalid signed ids found"
  end

  # Copy the files from ActiveStorage to the Stacks directory
  def shelve_files
    file_uploads_map.each do |filename, signed_id|
      blob = blob_for_signed_id(signed_id, filename)

      if Settings.features.awfl
        shelving_path = copy_file_to_content_addressed_storage(blob)
        create_link(filename, shelving_path)
      else
        shelving_path = File.join(stacks_druid_path, filename)
        FileUtils.mkdir_p(File.dirname(shelving_path))
        blob_path = ActiveStorage::Blob.service.path_for(blob.key)
        FileUtils.cp(blob_path, shelving_path)
      end
    end
  end

  # Builds a symlink in the legacy stacks filesystem to the shelving path (in content addressable storage)
  def create_link(filename, shelving_path)
    # There should be no need for this check. However we're not seeing the file on the filesystem, so check for now.
    raise "Path doesn't exist: `#{shelving_path}'" unless File.exist?(shelving_path)

    links_path = File.join(stacks_druid_path, filename)
    FileUtils.mkdir_p(File.dirname(links_path))
    File.unlink(links_path) if File.exist?(links_path) || File.symlink?(links_path)
    File.symlink(shelving_path, links_path)
  end

  def copy_file_to_content_addressed_storage(blob)
    hexdigest = base64_to_hexdigest(blob.checksum)
    shelving_path = File.join(content_addressable_path, hexdigest)
    FileUtils.mkdir_p(File.dirname(shelving_path))

    blob_path = ActiveStorage::Blob.service.path_for(blob.key)
    Rails.logger.info("Copying #{blob_path} to #{shelving_path}")
    FileUtils.cp(blob_path, shelving_path)
    shelving_path
  end

  def base64_to_hexdigest(base64)
    Base64.decode64(base64).unpack1('H*')
  end

  # return [ActiveStorage::Blob] the blob for the signed id
  def blob_for_signed_id(signed_id, filename)
    file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
    ActiveStorage::Blob.find(file_id)
  rescue ActiveRecord::RecordNotFound
    raise BlobError, "Unable to find upload for #{filename} (#{signed_id})"
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
      shelving_path = File.join(content_addressable_path, hexdigest)
      FileUtils.rm_f(shelving_path)
    end
  end

  def cocina_md5s
    cocina_files.map do |file|
      file.hasMessageDigests.find { |digest| digest.type == 'md5' }.digest
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
