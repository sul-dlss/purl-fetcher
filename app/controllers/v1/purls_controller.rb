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

      Racecar.produce_sync(value: { cocina: cocina_object, actions: nil }.to_json, key: druid_param, topic: "purl-updates")

      render json: true, status: :accepted
    end

    def destroy
      Purl.mark_deleted(druid_param)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

    def cocina_object
      Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format).to_unsafe_h)
    end
  end
end
