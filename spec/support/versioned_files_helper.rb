# Write a version of an object. Note that this does not correctly update an existing version.
# rubocop:disable Metrics/AbcSize
def write_version(content_path:, versions_path:, cocina_object:,
                  version_metadata: VersionedFilesService::VersionsManifest::VersionMetadata.new(1, 'available', DateTime.now),
                  version: 1)
  # Write original content files to s3
  s3_client = S3ClientFactory.create_client

  cocina_object.structural.contains.each do |file_set|
    file_set.structural.contains.each do |file|
      next unless file.administrative.shelve

      md5 = file.hasMessageDigests.first.digest
      s3_client.put_object(
        bucket: Settings.s3.bucket,
        key: "#{content_path}/#{md5}",
        body: file.filename
      )
    end
  end
  s3_client.put_object(
    bucket: Settings.s3.bucket,
    key: "#{versions_path}/cocina.#{version}.json",
    body: cocina_object.to_json
  )

  s3_client.put_object(
    bucket: Settings.s3.bucket,
    key: "#{versions_path}/public.#{version}.xml",
    body: PublicXmlWriter.generate(cocina_object)
  )

  s3_client.put_object(
    bucket: Settings.s3.bucket,
    key: "#{versions_path}/versions.json",
    body: { versions: { version => { state: 'available', date: version_metadata.date.iso8601 } }, head: version }.to_json
  )
end
# rubocop:enable Metrics/AbcSize

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
