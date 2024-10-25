# Determines the files that have been shelved for an object.
# Also, checks that the files actually exist on the shelves.
class FilesByMd5Service
  def self.call(...)
    new(...).call
  end

  # @param [Purl] purl
  def initialize(purl:)
    @purl = purl
  end

  # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files for all versions.
  # For example: [
  #   { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
  #   { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
  # ]
  def call
    if VersionedFilesService.versioned_files?(druid:)
      versioned_files_by_md5
    else
      unversioned_files_by_md5
    end
  end

  private

  attr_reader :purl

  delegate :druid, to: :purl

  def versioned_files_by_md5
    correct_and_present_files = versioned_files_object.file_details_by_md5.select do |file_details|
      md5_filename = versioned_files_object.content_path_for(md5: file_details.md5)
      md5_filesize = file_details.filesize
      check_exists_and_complete(md5_filename, md5_filesize)
    end
    filenames_by_md5(correct_and_present_files)
  end

  def versioned_files_object
    @versioned_files_object ||= VersionedFilesService::Object.new(druid)
  end

  def unversioned_files_by_md5
    # Check for handling purls mistakenly lacking a PublicJson record. Remove check once all have been republished.
    # See https://github.com/sul-dlss/dor-services-app/issues/5181
    return [] unless purl.public_json

    cocina = VersionedFilesService::Cocina.new(hash: purl.public_json.cocina_hash)
    correct_and_present_files = cocina.file_details_by_md5.select do |file_details|
      md5_filename = versioned_files_object.stacks_object_path.join(file_details.filename)
      md5_filesize = file_details.filesize
      check_exists_and_complete(md5_filename, md5_filesize)
    end
    filenames_by_md5(correct_and_present_files)
  end

  def filenames_by_md5(file_details_list)
    file_details_list.map do |file_details|
      { file_details.md5 => file_details.filename }
    end
  end

  def check_exists_and_complete(path, expected_size)
    context = { path: path.to_s, druid:, expected_size: }

    unless path.exist?
      Honeybadger.notify("File missing from shelves", context:)
      return false
    end

    actual_size = File.size(path)
    if actual_size != expected_size
      context[:actual_size] = actual_size
      Honeybadger.notify("File path present on shelves but file isn't the expected size. It's likely a bug shelved the wrong content.", context:)
      return false
    end

    true
  end
end
