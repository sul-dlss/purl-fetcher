# Write a version of an object. Note that this does not correctly update an existing version.
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/ParameterLists
def write_version(content_path:, versions_path:, stacks_object_path:, cocina_object:,
                  version_metadata: VersionedFilesService::VersionsManifest::VersionMetadata.new(1, 'available', DateTime.now),
                  version: 1)
  # Write original content files and symlink to stacks filesystem
  FileUtils.mkdir_p(content_path)
  cocina_object.structural.contains.each do |file_set|
    file_set.structural.contains.each do |file|
      next unless file.administrative.shelve

      md5 = file.hasMessageDigests.first.digest
      File.write("#{content_path}/#{md5}", file.filename)
      stacks_path = "#{stacks_object_path}/#{file.filename}"
      FileUtils.mkdir_p(File.dirname(stacks_path))
      File.link("#{content_path}/#{md5}", stacks_path) unless File.exist?(stacks_path)
    end
  end
  FileUtils.mkdir_p(versions_path)
  File.write("#{versions_path}/cocina.#{version}.json", cocina_object.to_json)
  FileUtils.rm_rf("#{versions_path}/cocina.json")
  File.link("#{versions_path}/cocina.#{version}.json", "#{versions_path}/cocina.json")
  File.write("#{versions_path}/public.#{version}.xml", PublicXmlWriter.generate(cocina_object))
  FileUtils.rm_rf("#{versions_path}/public.xml")
  File.link("#{versions_path}/public.#{version}.xml", "#{versions_path}/public.xml")
  File.write("#{versions_path}/versions.json", { versions: { version => { state: 'available', date: version_metadata.date.iso8601 } }, head: version }.to_json)
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/ParameterLists

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
