class UpdateStacksFilesService
  class BlobError < StandardError; end

  attr_reader :purl

  delegate :cocina_object, :stacks_druid_path, to: :purl

  def initialize(purl)
    @purl = purl
  end

  def write!
    shelve_files
    unshelve_removed_files
  end

  # Copy the files from ActiveStorage to the Stacks directory
  def shelve_files
    cocina_object.structural.contains.each do |fileset|
      fileset.structural.contains.each do |file|
        next unless signed_id?(file.externalIdentifier)

        blob = blob_for_signed_id(file.externalIdentifier, file.filename)
        blob_path = ActiveStorage::Blob.service.path_for(blob.key)
        FileUtils.mkdir_p(stacks_druid_path) unless File.directory?(stacks_druid_path)

        shelving_path = File.join(stacks_druid_path, file.filename)
        FileUtils.cp(blob_path, shelving_path) unless File.exist?(shelving_path)
      end
    end
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
      file = File.basename(file_with_path)
      next if file_in_cocina?(file)

      File.delete(file_with_path)
    end
  end

  # return [Boolean] whether the file is in the cocina object baesd on filename
  def file_in_cocina?(file_on_disk)
    cocina_object.structural.contains.map do |fileset|
      fileset.structural.contains.select { |file| file.filename == file_on_disk }
    end.flatten.any?
  end

  # return [Boolean] whether the file_id is an ActiveStorage signed_id
  def signed_id?(file_id)
    ActiveStorage.verifier.valid_message?(file_id)
  end
end
