module V1
  class PurlsController < ApplicationController
    include Authenticated

    before_action :check_auth_token, except: %i[show]
    before_action :load_cocina_object, only: %i[create]
    before_action :find_purl, except: %i[show]

    rescue_from UpdateStacksFilesService::RequestError, VersionedFilesService::BadFileTransferError do |e|
      render build_error('400', e, 'Bad request')
    end

    # Show the files that we have for this object. Used by DSA to know which files need to be shelved.
    def show
      # Causes a 404 for a deleted item, which might happen if a purl is deleted and then reused.
      purl = Purl.status('public').find_by!(druid: druid_param)
      render json: { files_by_md5: FilesByMd5Service.call(purl:) }
    end

    # POST /resource
    def create
      PurlCocinaUpdater.new(@purl, @cocina_object, version:).update if version >= @purl.version

      PurlAndStacksService.update(purl: @purl, cocina_object: @cocina_object, file_uploads:, version:, version_date:, must_version:)

      render json: true, location: @purl, status: :created
    end

    def destroy
      return render json: { error: "not yet published" }, status: :conflict if @purl.new_record?
      return render json: { error: "already deleted" }, status: :conflict if @purl.deleted?

      @purl.mark_deleted

      PurlAndStacksService.delete(purl: @purl)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    # This starts the release process.
    # The object must be shelved and published before calling this API endpoint.
    def release_tags
      return render json: { error: "not yet published" }, status: :not_found if @purl.new_record?

      ReleaseService.release(@purl, release_tag_params)

      render json: true, status: :accepted
    end

    private

    def find_purl
      @purl = begin
        Purl.find_or_initialize_by(druid: druid_param || @cocina_object.externalIdentifier)
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    end

    # Build the cocina object from the params
    def load_cocina_object
      cocina_model_params = resource_params.require(:object).to_unsafe_h
      @cocina_object = Cocina::Models.build(cocina_model_params)
    end

    def release_tag_params
      params.require(:actions).permit(index: [], delete: [])
    end

    # @return [Hash<String, String>] is a map of filenames to temporary UUIDs
    def file_uploads
      resource_params[:file_uploads].to_h
    end

    def version_date
      version_date = resource_params[:version_date]
      # TODO: Conditional can be removed once DSA is providing the version date.
      version_date ? DateTime.iso8601(version_date) : DateTime.now
    end

    def version
      version = resource_params[:version]
      # TODO: Once DSA is providing the version, || '1' can be removed.
      version&.to_i || 1
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
      params.permit(:version_date, :version, :must_version, file_uploads: {}, object: {})
    end
  end
end
