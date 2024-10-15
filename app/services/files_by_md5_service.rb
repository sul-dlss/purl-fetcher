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
    versioned_files_object.files_by_md5.select { |md5_file| check_exists(versioned_files_object.content_path_for(md5: md5_file.keys.first)) }
  end

  def versioned_files_object
    @versioned_files_object ||= VersionedFilesService::Object.new(druid)
  end

  def unversioned_files_by_md5
    # Check for handling purls mistakenly lacking a PublicJson record. Remove check once all have been republished.
    # See https://github.com/sul-dlss/dor-services-app/issues/5181
    return [] unless purl.public_json

    cocina = VersionedFilesService::Cocina.new(hash: purl.public_json.cocina_hash)
    cocina.files_by_md5.select { |md5_file| check_exists(versioned_files_object.stacks_object_path.join(md5_file.values.first)) }
  end

  def check_exists(path)
    if path.exist?
      true
    else
      Honeybadger.notify("File missing from shelves", context: { path: path.to_s, druid: })
      false
    end
  end
end
