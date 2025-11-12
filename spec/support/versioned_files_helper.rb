# Write a version of an object. Note that this does not correctly update an existing version.
def write_version(cocina_object:,
                  version_metadata: VersionedFilesService::VersionsManifest::VersionMetadata.new(1, 'available', DateTime.now),
                  version: 1)
  # Write original content files to s3
  object_store = ObjectStore.new(druid: cocina_object.externalIdentifier)

  cocina_object.structural.contains.each do |file_set|
    file_set.structural.contains.each do |file|
      next unless file.administrative.shelve

      md5 = file.hasMessageDigests.first.digest

      object_store.put("content/#{md5}", file.filename)
    end
  end
  object_store.put("versions/cocina.#{version}.json", cocina_object.to_json)
  object_store.put("versions/public.#{version}.xml", PublicXmlWriter.generate(cocina_object))
  object_store.put("versions/versions.json", { versions: { version => { state: 'available', date: version_metadata.date.iso8601 } }, head: version }.to_json)
end

def read_file(key)
  s3_client = S3ClientFactory.create_client
  resp = s3_client.get_object(bucket: Settings.s3.bucket, key: key)
  resp.body.read
end

def write_file_transfers(file_transfers:, access_transfer_stage:)
  file_transfers.each do |filename, transfer_uuid|
    File.write("#{access_transfer_stage}/#{transfer_uuid}", filename)
  end
end

RSpec::Matchers.define :link_to do |expected|
  match do |actual|
    File.exist?(actual) && File.exist?(expected) && File.stat(actual).ino == File.stat(expected).ino
  end
end
