module V1
  class ReleasedController < ApplicationController
    # Query for all druids that have a certain release tag.
    # This is used by the sitemap generator in PURL.
    def show
      release_tag = params[:release_tag]
      purls = Purl.published
                  .status('public')
                  .target(release_tag).pluck(:druid, :updated_at)

      render json: purls.map { |(druid, updated_at)| { druid:, updated_at: } }
    end
  end
end
