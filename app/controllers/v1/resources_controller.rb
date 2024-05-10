# frozen_string_literal: true

module V1
  class ResourcesController < ApplicationController
    include Authenticated

    class BlobError < StandardError; end

    before_action :check_auth_token, only: %i[create]

    # POST /resource
    def create
      begin
        @druid = cocina_object.externalIdentifier
        shelve_files
        unshelve_removed_files
        location = write_purl
      rescue BlobError => e
        # Returning 500 because not clear whose fault it is.
        return render build_error('500', e, 'Error matching uploading files to file parameters.')
      end

      render json: true, location:, status: :created
    end

    private

    attr_reader :druid

    # return [String] the Purl path for the druid
    def purl_druid_path
      DruidTools::PurlDruid.new(druid, Settings.filesystems.purl_root).path
    end

    # return [String] the Stacks path for the druid
    def stacks_druid_path
      DruidTools::PurlDruid.new(druid, Settings.filesystems.stacks_root).path
    end

    # Write the cocina object to the Purl druid path as cocina.json
    # return [String] the path to the written cocina.json file
    def write_purl
      cocina_json_path = File.join(purl_druid_path, 'cocina.json')
      FileUtils.mkdir_p(purl_druid_path) unless File.directory?(purl_druid_path)
      File.write(cocina_json_path, cocina_object.to_json)

      purl = begin
        Purl.find_or_create_by(druid:)
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: druid, topic: "purl-updates")

      purl
    end

    CREATE_PARAMS_EXCLUDE_FROM_COCINA = %i[action controller resource].freeze

    def cocina_object_params
      params.except(*CREATE_PARAMS_EXCLUDE_FROM_COCINA).to_unsafe_h
    end

    # Build the cocina object from the params
    def cocina_object
      cocina_model_params = cocina_object_params.deep_dup
      @cocina_object ||= Cocina::Models.build(cocina_model_params)
    end

    # return [Array<Cocina::Models::FileSet>] the file sets in the cocina object
    def file_sets
      cocina_object.structural.contains
    end

    # Copy the files from ActiveStorage to the Stacks directory
    def shelve_files
      file_sets.each do |fileset|
        fileset.structural.contains.each do |file|
          next unless signed_id?(file.externalIdentifier)

          blob = blob_for_signed_id(file.externalIdentifier, file.filename)
          blob_path = ActiveStorage::Blob.service.path_for(blob.key)
          FileUtils.mkdir_p(stacks_druid_path) unless File.directory?(stacks_druid_path)

          shelving_path = File.join(stacks_druid_path, file.filename)
          FileUtils.cp(blob_path, shelving_path) unless File.exist?(shelving_path)
        end
      end
    end

    # return [ActiveStorage::Blob] the blob for the signed id
    def blob_for_signed_id(signed_id, filename)
      file_id = ActiveStorage.verifier.verified(signed_id, purpose: :blob_id)
      ActiveStorage::Blob.find(file_id)
    rescue ActiveRecord::RecordNotFound
      raise BlobError, "Unable to find upload for #{filename} (#{signed_id})"
    end

    # Remove files from the Stacks directory that are not in the cocina object
    def unshelve_removed_files
      Dir.glob("#{stacks_druid_path}/**/*") do |file_with_path|
        file = File.basename(file_with_path)
        next if file_in_cocina?(file)

        File.delete(file_with_path)
      end
    end

    # return [Boolean] whether the file is in the cocina object baesd on filename
    def file_in_cocina?(file_on_disk)
      cocina_object.structural.contains.map do |fileset|
        fileset.structural.contains.select { |file| file.filename == file_on_disk }
      end.flatten.any?
    end

    # return [Boolean] whether the file_id is an ActiveStorage signed_id
    def signed_id?(file_id)
      ActiveStorage.verifier.valid_message?(file_id)
    end

    # JSON-API error response. See https://jsonapi.org/.
    def build_error(error_code, err, msg)
      {
        json: {
          errors: [
            {
              status: error_code,
              title: msg,
              detail: err.message
            }
          ]
        },
        content_type: 'application/vnd.api+json',
        status: error_code
      }
    end
  end
end
