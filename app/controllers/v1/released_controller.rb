module V1
  class ReleasedController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[update]

    # Query for all druids that have a certain release tag.
    # This is used by the sitemap generator in PURL.
    def show
      release_tag = params[:id]
      purls = Purl.published
                  .status('public')
                  .target(release_tag).pluck(:druid, :updated_at)

      render json: purls.map { |(druid, updated_at)| { druid:, updated_at: } }
    end

    # This starts the release process.
    # The object must be shelved and published before calling this API endpoint.
    def update
      purl = Purl.find_by!(druid: params[:druid])
      actions = params.require(:actions).permit(index: [], delete: [])

      ReleaseService.release(purl, actions)

      render json: true, status: :accepted
    end
  end
end
