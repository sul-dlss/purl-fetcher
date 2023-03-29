module V1
  class CollectionsController < ApplicationController
    ##
    # API call to get purls for a specific collection
    # Used in Exhibits Purl#items (https://github.com/sul-dlss/exhibits/blob/2f79f24d0dc669c384abd402e51714cd103eaa44/app/models/purl.rb#L22)
    #   via https://github.com/sul-dlss/purl_fetcher-client/blob/d03ff4db6271bb265ca33f0313387f88b60ed4e9/lib/purl_fetcher/client/public_xml_record.rb#L143-L147
    def purls
      @purls = Purl.joins(:collections)
                   .where(collections: { druid: druid_param })
                   .page(page_params[:page])
                   .per(per_page_params[:per_page])
    end
  end
end
