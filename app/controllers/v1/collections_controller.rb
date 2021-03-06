module V1
  class CollectionsController < ApplicationController
    ##
    # API call to get a full list of all PURL collections, paginated of course.
    #
    def index
      @collections = Purl.where(object_type: ['collection', 'collection|set'])
                         .includes(:release_tags)
                         .page(page_params[:page])
                         .per(per_page_params[:per_page])
    end

    ##
    # API call to get information about a specific collection
    #
    def show
      @collection = Purl.find_by_druid!(druid_param)
    end

    ##
    # API call to get purls for a specific collection
    #
    def purls
      @purls = Purl.joins(:collections)
                   .where(collections: { druid: druid_param })
                   .page(page_params[:page])
                   .per(per_page_params[:per_page])
    end
  end
end
