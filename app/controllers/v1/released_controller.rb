module V1
  class ReleasedController < ApplicationController
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
      cocina = purl.cocina_hash

      # TODO: in the future this can just refresh_release_tags and produce_indexer_log_message
      Racecar.produce_sync(value: { cocina:, actions: }.to_json, key: druid_param, topic: "purl-updates")

      render json: true, status: :accepted
    end
  end
end
