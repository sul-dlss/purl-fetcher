class UpdateStacksFilesService
  class BlobError < StandardError; end
  class RequestError < StandardError; end

  def self.write!(...)
    new(...).write!
  end

  def initialize(purl, file_uploads_map)
    @purl = purl
    @file_uploads_map = file_uploads_map
  end

  def write!
    check_files_in_structural
    check_signed_ids
    shelve_files
    unshelve_removed_files
  end

  private

  attr_reader :purl, :file_uploads_map

  delegate :cocina_object, :stacks_druid_path, to: :purl

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
      blob_path = ActiveStorage::Blob.service.path_for(blob.key)

      shelving_path = File.join(stacks_druid_path, filename)
      make_shelving_dir(shelving_path)
      FileUtils.cp(blob_path, shelving_path)
    end
  end

  def make_shelving_dir(shelving_path)
    shelving_dir = File.dirname(shelving_path)
    return if File.directory?(shelving_dir)

    FileUtils.mkdir_p(shelving_dir)
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
    Dir.glob("#{stacks_druid_path}/**/*") do |file_with_path|
      file = file_with_path.delete_prefix("#{stacks_druid_path}/")
      next if cocina_filenames.include?(file)

      File.delete(file_with_path)
    end
  end

  def cocina_filenames
    @cocina_filenames ||= cocina_object.structural.contains.map do |fileset|
      fileset.structural.contains.map(&:filename)
    end.flatten
  end
end
