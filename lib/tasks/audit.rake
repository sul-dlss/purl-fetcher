# frozen_string_literal: true

namespace :audit do
  desc 'Audit all shelved files in the repository'
  task files: :environment do
    puts "Starting audit of shelved files..."
    puts "Searching for versions.json files in: #{Settings.filesystems.stacks_root}"

    object_count = 0

    # Find all versions.json files in the stacks root directory
    version_manifests = `find "#{Settings.filesystems.stacks_root}" -name "versions.json" -type f 2>/dev/null`.split("\n")
    if version_manifests.empty?
      puts "No versions.json files found in #{Settings.filesystems.stacks_root}"
      next
    end

    version_manifests.each do |version_file_path|
      object_count += 1
      expected_files = find_shelved_files_for_all_versions(version_file_path)

      next if expected_files.empty? # Metadata only object

      druid_path = File.dirname(version_file_path).delete_suffix('/versions')

      found_files = Dir.entries("#{druid_path}/content").reject { |f| f.start_with?('.') }.to_set

      next if expected_files == found_files

      puts "In #{druid_path}, expected #{expected_files} files but found #{found_files}"
    rescue StandardError => e
      puts "  ERROR: Failed to process #{version_file_path}: #{e.message}"
    end

    puts "\n\nAudit complete. Scanned #{object_count} objects."
  end
end

def find_shelved_files_for_all_versions(version_file_path)
  version_data = JSON.parse(File.read(version_file_path))

  version_data['versions'].keys.flat_map do |version|
    # Parse the cocina.json file
    cocina_file_path = File.join druid_path, "/versions/cocina.#{version}.json"
    cocina_data = JSON.parse(File.read(cocina_file_path))

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
