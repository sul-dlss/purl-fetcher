module V1
  class PurlsController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[update destroy]
    before_action :find_purl, only: %i[update destroy]

    # Show the files that we have for this object. Used by DSA to know which files need to be shelved.
    def show
      # Causes a 404 for a deleted item, which might happen if a purl is deleted and then reused.
      purl = Purl.status('public').find_by!(druid: druid_param)
      render json: { files_by_md5: purl.public_json.files_by_md5 }
    end

    ##
    # Update the database purl record from the passed in cocina.
    # This is a legacy API and will be replaced by ResourcesController#create
    def update
      PurlCocinaUpdater.update(@purl, Cocina::Models.without_metadata(cocina_object))
      write_public_files

      render json: true, status: :accepted
    end

    def destroy
      return render json: { error: "already deleted" }, status: :conflict if @purl.deleted?

      @purl.mark_deleted
      UpdatePurlMetadataService.new(@purl).delete!
      UpdateStacksFilesService.delete!(@purl.cocina_object)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

    def find_purl
      @purl = begin
        Purl.find_or_create_by(druid: druid_param)
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    end

    def cocina_object
      @cocina_object ||= Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format).to_unsafe_h)
    end

    def write_public_files
      FileUtils.mkdir_p(@purl.purl_druid_path) unless File.directory?(@purl.purl_druid_path)
      PublicCocinaWriter.write(cocina_object, File.join(@purl.purl_druid_path, 'cocina.json'))
      PublicXmlWriter.write(cocina_object, File.join(@purl.purl_druid_path, 'public'))
    end
  end
end
