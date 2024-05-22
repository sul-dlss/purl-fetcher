# frozen_string_literal: true

module V1
  class ResourcesController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[create]
    before_action :load_cocina_object
    before_action :load_purl

    # POST /resource
    def create
      begin
        UpdateStacksFilesService.new(@cocina_object).write!
        UpdatePurlMetadataService.new(@cocina_object).write!
      rescue UpdateStacksFilesService::BlobError => e
        # Returning 500 because not clear whose fault it is.
        return render build_error('500', e, 'Error matching uploading files to file parameters.')
      end

      render json: true, location: @purl, status: :created
    end

    private

    CREATE_PARAMS_EXCLUDE_FROM_COCINA = %i[action controller resource].freeze

    def cocina_object_params
      params.except(*CREATE_PARAMS_EXCLUDE_FROM_COCINA).to_unsafe_h
    end

    # Build the cocina object from the params
    def load_cocina_object
      cocina_model_params = cocina_object_params.deep_dup
      @cocina_object = Cocina::Models.build(cocina_model_params)
    end

    def load_purl
      Purl.find_or_create_by(druid: @cocina_object.externalIdentifier)
    rescue ActiveRecord::RecordNotUnique
      retry
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
