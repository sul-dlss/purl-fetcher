class ContentAddressedStorage
  def initialize(druid)
    awfl_directory = DruidTools::Druid.new(druid, Settings.filesystems.stacks_content_addressable).path
    @content_addressable_path = "#{awfl_directory}/content"
  end

  attr_reader :content_addressable_path

  # Move the file at file_path into the content addressed file store using md5 as the key.
  # @returns [String] the path to the file in the store.
  def mv(file_path:, md5:)
    shelving_path = File.join(content_addressable_path, md5)
    FileUtils.mkdir_p(File.dirname(shelving_path))

    Rails.logger.info("Moving #{file_path} to #{shelving_path}")
    FileUtils.mv(file_path, shelving_path)
    shelving_path
  end

  # Delete the file stored with key md5 from the content addressed file store
  def delete(md5:)
    shelving_path = File.join(content_addressable_path, md5)
    FileUtils.rm_f(shelving_path)
  end
end
