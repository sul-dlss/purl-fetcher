module V1
  class PurlsController < ApplicationController
    ##
    # Returns all Purls with filtering options
    def index
      @purls = Purl.all
                   .includes(:collections, :release_tags)
                   .filter(filter_params)
                   .membership(membership_param)
                   .page(page_params[:page])
                   .per(per_page_params[:per_page])
    end

    ##
    # Returns a specific Purl by a Purl
    def show
      @purl = Purl.find_by_druid(druid_param)
    end

    private

      def filter_params
        object_type_param
      end

      def object_type_param
        params.permit(:object_type)
      end

      def membership_param
        params.permit(:membership)
      end
  end
end