# frozen_string_literal: true

module V1
  class ResourcesController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[create]
    before_action :load_cocina_object, only: %i[create]
    before_action :load_purl

    rescue_from UpdateStacksFilesService::RequestError, VersionedFilesService::BadFileTransferError do |e|
      render build_error('400', e, 'Bad request')
    end

    # POST /resource
    def create
      PurlCocinaUpdater.new(@purl, @cocina_object).update

      PurlAndStacksService.update(purl: @purl, cocina_object: @cocina_object, file_uploads:, version:, version_date:, must_version:)

      render json: true, location: @purl, status: :created
    end

    private

    # Build the cocina object from the params
    def load_cocina_object
      cocina_model_params = resource_params.require(:object).to_unsafe_h
      @cocina_object = Cocina::Models.build(cocina_model_params)
    end

    def load_purl
      @purl = Purl.find_or_create_by(druid: @cocina_object.externalIdentifier)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    # @return [Hash<String, String>] is a map of filenames to temporary UUIDs
    def file_uploads
      resource_params[:file_uploads].to_h
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
        content_type: 'application/json',
        status: error_code
      }
    end

    def version_date
      version_date = resource_params[:version_date]
      # TODO: Conditional can be removed once DSA is providing the version date.
      version_date ? DateTime.iso8601(version_date) : DateTime.now
    end

    def version
      version = resource_params[:version]
      # TODO: Once DSA is providing the version, || '1' can be removed.
      version || '1'
    end

    def must_version
      # This allows DSA to indicate that the object must be in the versioned layout.
      # TODO: This is a temporary parameter until migration is complete.
      # It is necessary so that DSA that a previously unversioned object now has versions.
      resource_params[:must_version] || false
    end

    # @return [Hash]
    #   * :file_uploads [Hash<String, String>] map of cocina filenames to staging filenames (UUIDs)
    #   * :version_date [String] the version date (in ISO8601 format)
    #   * :version [String] the version of the item
    #   * :must_version [String] whether the item must be versioned
    #   * :object [Hash] the Cocina data object
    def resource_params
      params.require(:resource).permit(:version_date, :version, :must_version, file_uploads: {}, object: {})
    end
  end
end
