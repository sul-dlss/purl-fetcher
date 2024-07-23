# frozen_string_literal: true

module V1
  class ResourcesController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[create]
    before_action :load_cocina_object
    before_action :load_purl

    rescue_from UpdateStacksFilesService::RequestError, VersionedFilesService::BadFileTransferError do |e|
      render build_error('400', e, 'Bad request')
    end

    # POST /resource
    def create
      PurlCocinaUpdater.new(@purl, @cocina_object).update

      PurlAndStacksService.update(purl: @purl, cocina_object: @cocina_object, file_uploads:, version:, version_date:)

      render json: true, location: @purl, status: :created
    end

    private

    # Build the cocina object from the params
    def load_cocina_object
      cocina_model_params = params.require(:resource).require(:object).to_unsafe_h
      @cocina_object = Cocina::Models.build(cocina_model_params)
    end

    def load_purl
      @purl = Purl.find_or_create_by(druid: @cocina_object.externalIdentifier)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    # @return [Hash<String, String>] is a map of filenames to temporary UUIDs
    def file_uploads
      params.require(:resource).permit![:file_uploads].to_h
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
      version_date = params.require(:resource)[:version_date]
      # TODO: Conditional can be removed once DSA is providing the version date.
      version_date ? DateTime.iso8601(version_date) : DateTime.now
    end

    def version
      version = params.require(:resource)[:version]
      # TODO: Once DSA is providing the version, || '1' can be removed.
      version || '1'
    end
  end
end
