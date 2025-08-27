# frozen_string_literal: true

namespace :audit do # rubocop:disable Metrics/BlockLength
  desc 'Audit all shelved files in the repository'
  task files: :environment do # rubocop:disable Metrics/BlockLength
    puts "Starting audit of shelved files..."
    puts "Searching for cocina.json files in: #{Settings.filesystems.stacks_root}"

    missing_files = []
    total_cocina_files = 0
    total_shelved_files = 0

    # Find all cocina.json files in the stacks root directory
    cocina_files = `find "#{Settings.filesystems.stacks_root}" -name "cocina.json" -type f 2>/dev/null`.split("\n")

    if cocina_files.empty?
      puts "No cocina.json files found in #{Settings.filesystems.stacks_root}"
      next
    end

    cocina_files.each do |cocina_file_path|
      total_cocina_files += 1

      begin
        # Parse the cocina.json file
        cocina_data = JSON.parse(File.read(cocina_file_path))

        # Extract the druid from the cocina file path or data
        druid = cocina_data['externalIdentifier'].split(':').last

        puts "Auditing #{druid} (#{cocina_file_path})"

        # Find all shelved files in the cocina data structure
        shelved_files = find_shelved_files(cocina_data)

        if shelved_files.empty?
          puts "  No shelved files found"
          next
        end

        total_shelved_files += shelved_files.count
        puts "  Found #{shelved_files.count} shelved files"

        # Check if each shelved file exists
        shelved_files.each do |file_info|
          filename = file_info['hasMessageDigests'].find { it['type'] == 'md5' }['digest']

          # Construct the full path to the shelved file
          # Files are stored in the stacks directory structure
          stacks_object_path = File.dirname(cocina_file_path.gsub('/versions/cocina.json', '')) + "/#{druid}/content"
          file_path = File.join(stacks_object_path, filename)

          next if File.exist?(file_path)

          warning_msg = "WARNING: Shelved file does not exist - #{filename} (expected at #{file_path})"
          puts "  #{warning_msg}"
          missing_files << {
            druid: druid,
            filename: filename,
            expected_path: file_path,
            cocina_file: cocina_file_path
          }
        end
      rescue JSON::ParserError => e
        puts "  ERROR: Failed to parse JSON in #{cocina_file_path}: #{e.message}"
      rescue StandardError => e
        puts "  ERROR: Failed to process #{cocina_file_path}: #{e.message}"
      end
    end

    # Summary
    puts "\n#{'=' * 80}"
    puts "AUDIT SUMMARY"
    puts "=" * 80
    puts "Total cocina.json files processed: #{total_cocina_files}"
    puts "Total shelved files found: #{total_shelved_files}"
    puts "Missing shelved files: #{missing_files.count}"

    if missing_files.any?
      puts "\nMISSING FILES DETAILS:"
      puts "-" * 40
      missing_files.each do |missing_file|
        puts "DRUID: #{missing_file[:druid]}"
        puts "  File: #{missing_file[:filename]}"
        puts "  Expected: #{missing_file[:expected_path]}"
        puts "  Cocina: #{missing_file[:cocina_file]}"
        puts ""
      end
    else
      puts "\nAll shelved files are present! ✓"
    end
  end
end

def find_shelved_files(cocina_data)
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
      shelved_files << file if file.dig('administrative', 'shelve') == true
    end
  end

  shelved_files
end
