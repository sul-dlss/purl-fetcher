module V1
  class ReleasedController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[update]

    def show
      release_tag = params[:id]
      purls = Purl.published
                  .status('public')
                  .target(release_tag).pluck(:druid, :updated_at)

      render json: purls.map { |(druid, updated_at)| { druid:, updated_at: } }
    end

    # TODO: this will eventually replace the releaseTag parsing in PurlsController#update
    def update
      purl = Purl.find_by!(druid: params[:druid])
      actions = params.require(:actions).permit(index: [], delete: [])

      # add the release tags, and reuse tags if already associated with this PURL
      purl.refresh_release_tags(actions)
      purl.save!
      purl.produce_indexer_log_message

      render json: true, status: :accepted
    end
  end
end
