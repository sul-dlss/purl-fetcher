module V1
  class PurlsController < ApplicationController
    ##
    # Returns all Purls with filtering options
    def index
      @purls = Purl.all
                   .includes(:collections, :release_tags)
                   .with_filter(filter_params)
                   .status(status_param)
                   .target(target_param)
                   .membership(membership_param)
                   .page(page_params[:page])
                   .per(per_page_params[:per_page])
    end

    ##
    # Returns a specific Purl by a Purl
    def show
      @purl = Purl.find_by_druid!(druid_param)
    end

    ##
    # Update the database purl record from the passed in cocina
    def update
      @purl = begin
                Purl.find_or_create_by(druid: druid_param)
              rescue ActiveRecord::RecordNotUnique
                retry
              end

      if params[:type]
        # Racecar.produce_sync(value: cocina_object.to_json, key: druid_param, topic: "purl-update")
        PurlCocinaUpdater.new(@purl, cocina_object).update
      else
        # This path is a fallback used until dor-services-app is providing the data we need
        Honeybadger.notify("Cocina JSON was not provided. Falling back to xml", context: { druid: druid_param })
        PurlXmlUpdater.new(@purl).update
      end

      render json: true
    end

    def destroy
      Purl.mark_deleted(druid_param)
    end

    private

      def cocina_object
        Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format).to_unsafe_h)
      end

      def filter_params
        object_type_param
      end

      def object_type_param
        params.permit(:object_type)
      end

      def membership_param
        params.permit(:membership)
      end

      def status_param
        params.permit(:status)
      end

      def target_param
        params.permit(:target)
      end
  end
end
