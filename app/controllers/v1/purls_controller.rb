module V1
  class PurlsController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[update destroy]

    # Show the public json for the object. Used by purl to know if this object should be indexed by crawlers.
    def show
      purl = Purl.find_by!(druid: druid_param)
      render json: purl.as_public_json
    end

    ##
    # Update the database purl record from the passed in cocina.
    # This is a legacy API and will be replaced by ResourcesController#create
    def update
      @purl = begin
                Purl.find_or_create_by(druid: druid_param)
              rescue ActiveRecord::RecordNotUnique
                retry
              end

      begin
        PurlCocinaUpdater.update(@purl, cocina_object)
        write_public_files

        render json: true, status: :accepted
      rescue Cocina::Models::ValidationError => e
        render json: {
          errors: [
            { title: 'bad request', detail: e.message }
          ]
        }, status: :bad_request
      end
    end

    def destroy
      Purl.mark_deleted(druid_param)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

    def cocina_object
      @cocina_object ||= Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format, *Cocina::Models::METADATA_KEYS).to_unsafe_h)
    end

    def write_public_files
      FileUtils.mkdir_p(@purl.purl_druid_path) unless File.directory?(@purl.purl_druid_path)
      PublicCocinaWriter.write(cocina_object, File.join(@purl.purl_druid_path, 'cocina.json'))
      PublicXmlWriter.write(cocina_object, File.join(@purl.purl_druid_path, 'public'))
    end
  end
end
