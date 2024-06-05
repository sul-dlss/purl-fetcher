class FileUploadValidator
  class Error < StandardError; end

  def self.validate(...)
    new(...).validate
  end

  def initialize(cocina_object:, file_uploads_map:)
    @cocina_object = cocina_object
    @file_uploads_map = file_uploads_map
  end

  def validate
    validate_files_in_structural
    validate_signed_ids
  end

  def validate_files_in_structural
    return if file_uploads_map.keys.all? { |filename| cocina_filenames.include?(filename) }

    raise Error, 'Files in file_uploads not in cocina object'
  end

  def validate_signed_ids
    return if file_uploads_map.values.all? { |signed_id| ActiveStorage.verifier.valid_message?(signed_id) }

    raise Error, "Invalid signed ids found"
  end

  private

  attr_reader :cocina_object, :file_uploads_map

  def cocina_filenames
    @cocina_filenames ||= cocina_object.structural.contains.map do |fileset|
      fileset.structural.contains.map(&:filename)
    end.flatten
  end
end
