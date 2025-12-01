# Determines the files that have been shelved for an object.
# Also, checks that the files actually exist on the shelves.
class FilesByMd5Service
  def self.call(...)
    new(...).call
  end

  # @param [Purl] purl
  def initialize(purl:)
    @purl = purl
    @object_store = ObjectStore.new(druid:)
  end

  # @return [Array<Hash<String, String>>] array of hashes with md5 as key and filename as value for shelved files for all versions.
  # For example: [
  #   { "5b79c8570b7ef582735f912aa24ce5f2" => "2542A.tiff" },
  #   { "cd5ca5c4666cfd5ce0e9dc8c83461d7a" => "2542A.jp2" }
  # ]
  def call
    correct_and_present_files = versioned_files_object.file_details_by_md5.select do |file_details|
      check_exists_and_complete(md5: file_details.md5, expected_size: file_details.filesize)
    end
    filenames_by_md5(correct_and_present_files)
  end

  private

  attr_reader :purl

  delegate :druid, to: :purl

  def versioned_files_object
    @versioned_files_object ||= VersionedFilesService::Object.new(druid)
  end

  def filenames_by_md5(file_details_list)
    file_details_list.map do |file_details|
      { file_details.md5 => file_details.filename }
    end
  end

  def check_exists_and_complete(md5:, expected_size:)
    context = { file_md5: md5, druid:, expected_size: }
    content_length = @object_store.content_length(md5:)

    if content_length != expected_size
      context[:actual_size] = content_length
      Honeybadger.notify("File path present on shelves but file isn't the expected size. It's likely a bug shelved the wrong content.", context:)
      return false
    end

    true
  rescue ObjectStore::NotFoundError
    Honeybadger.notify("File missing from shelves", context:)
    false
  end
end
