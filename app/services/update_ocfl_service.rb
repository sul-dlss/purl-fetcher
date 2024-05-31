class UpdateOcflService
  class BlobError < StandardError; end

  COCINA_JSON = 'cocina.json'.freeze
  PUBLIC_XML = 'public.xml'.freeze

  def self.write!(...)
    new(...).write!
  end

  def initialize(purl, file_uploads_map)
    @purl = purl
    @file_uploads_map = file_uploads_map
    @cocina_tempfile = Tempfile.new(COCINA_JSON)
    @public_xml_tempfile = Tempfile.new(PUBLIC_XML)
  end

  def write!
    add_files
    add_cocina_json
    add_public_xml
    remove_files
    ocfl_version.save
  ensure
    cocina_tempfile.close
    cocina_tempfile.unlink
    public_xml_tempfile.close
    public_xml_tempfile.unlink
  end

  private

  attr_reader :purl, :file_uploads_map, :cocina_tempfile, :public_xml_tempfile

  delegate :stacks_druid_path, to: :purl

  # Copy the files from ActiveStorage to ocfl
  def add_files
    file_uploads_map.each do |filename, signed_id|
      blob = blob_for_signed_id(signed_id, filename)
      blob_path = ActiveStorage::Blob.service.path_for(blob.key)

      ocfl_version.copy_file(blob_path, destination_path: filename)
    end
  end

  def add_cocina_json
    PublicCocinaWriter.write(purl.cocina_object, cocina_tempfile.path)
    ocfl_version.copy_file(cocina_tempfile.path, destination_path: COCINA_JSON)
  end

  def add_public_xml
    PublicXmlWriter.write(purl.cocina_object, public_xml_tempfile.path)
    ocfl_version.copy_file(public_xml_tempfile.path, destination_path: PUBLIC_XML)
  end

  # return [ActiveStorage::Blob] the blob for the signed id
  def blob_for_signed_id(signed_id, filename)
    file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
    ActiveStorage::Blob.find(file_id)
  rescue ActiveRecord::RecordNotFound
    raise BlobError, "Unable to find upload for #{filename} (#{signed_id})"
  end

  # Remove files from the ocfl that are not in the cocina object
  def remove_files
    save_filenames = cocina_filenames + [COCINA_JSON, PUBLIC_XML]
    ocfl_files_to_delete = ocfl_version.file_names.reject { |ocfl_file| save_filenames.include?(ocfl_file) }
    ocfl_files_to_delete.each do |ocfl_file|
      ocfl_version.delete_file(ocfl_file)
    end
  end

  def druid
    purl.druid
  end

  def ocfl_druid_path
    @ocfl_druid_path ||= DruidTools::AccessDruid
                         .new(druid, Settings.filesystems.ocfl_root)
                         .path
  end

  def directory
    @directory ||= OCFL::Object::Directory.new(object_root: ocfl_druid_path)
  end

  def ocfl_version
    @ocfl_version ||= if directory.exists?
                        directory.head_version
                      else
                        builder = OCFL::Object::DirectoryBuilder.new(object_root: ocfl_druid_path, id: druid)
                        builder.create_object_directory
                        builder.version
                      end
  end

  def cocina_filenames
    @cocina_filenames ||= purl.cocina_object.structural.contains.map do |fileset|
      fileset.structural.contains.map(&:filename)
    end.flatten
  end
end
