# frozen_string_literal: true

module V1
  class ResourcesController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[create]
    before_action :load_cocina_object
    before_action :load_purl

    rescue_from UpdateStacksFilesService::BlobError do |e|
      render build_error('500', e, 'Error matching uploading files to file parameters.')
    end

    rescue_from UpdateStacksFilesService::RequestError do |e|
      render build_error('400', e, 'Bad request')
    end

    # POST /resource
    def create
      PurlCocinaUpdater.new(@purl, @cocina_object).update

      UpdateStacksFilesService.write!(@cocina_object, file_uploads) unless @cocina_object.collection?
      UpdatePurlMetadataService.new(@purl).write!

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
  end
end
