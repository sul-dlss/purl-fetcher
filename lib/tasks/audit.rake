# frozen_string_literal: true

namespace :audit do
  desc 'Audit all shelved files in the repository'
  task files: :environment do
    puts "Starting audit of shelved files..."
    puts "Searching for versions.json files"

    object_count = 0

    # Find all versions.json files in the stacks root directory
    if version_manifests.empty?
      puts "No versions.json files found"
      next
    end

    regex = %r{/([^/]*)/versions/version\.json$}

    version_manifests.each do |version_file_path|
      match_data = regex.match(version_file_path)
      druid = match_data[1]
      object_store = ObjectStore.new(druid:)

      object_count += 1
      expected_files = find_shelved_files_for_all_versions(object_store)

      next if expected_files.empty? # Metadata only object

      found_files = object_store.content_md5s

      next if expected_files == found_files

      puts "In #{druid_path}, expected #{expected_files} files but found #{found_files}"
    rescue StandardError => e
      puts "  ERROR: Failed to process #{version_file_path}: #{e.message}"
    end

    puts "\n\nAudit complete. Scanned #{object_count} objects."
  end
end

def version_manifests
  @version_manifests ||= begin
    matching_files = []
    continuation_token = nil
    s3_client = S3ClientFactory.create_client
    loop do
      response = s3_client.list_objects_v2(
        bucket: Settings.s3.bucket_name,
        continuation_token: continuation_token
      )

      # Filter objects by suffix
      response.contents.each do |object|
        matching_files << object.key if object.key.end_with?('versions/version.json')
      end

      continuation_token = response.next_continuation_token
      break unless continuation_token
    end
    matching_files
  end
end

def find_shelved_files_for_all_versions(object_store)
  VersionedFilesService::VersionsManifest.new(object_store:).versions do |version|
    # Parse the cocina.json file
    cocina_data = object_store.read_cocina(version)

    # Find all shelved files in the cocina data structure
    find_shelved_files_for_version(cocina_data)
  end.to_set
end

def find_shelved_files_for_version(cocina_data)
  shelved_files = []

  # Navigate the cocina structure to find shelved files
  # Structure: structural -> contains (file sets) -> structural -> contains (files)
  file_sets = cocina_data.dig('structural', 'contains')

  return [] unless file_sets.is_a?(Array)

  file_sets.each do |file_set|
    files = file_set.dig('structural', 'contains')
    next unless files.is_a?(Array)

    files.each do |file|
      # Check if this file is marked for shelving
      shelved_files << file['hasMessageDigests'].find { it['type'] == 'md5' }['digest'] if file.dig('administrative', 'shelve') == true
    end
  end

  shelved_files
end
