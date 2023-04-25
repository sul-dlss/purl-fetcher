module V1
  class PurlsController < ApplicationController
    ##
    # Update the database purl record from the passed in cocina
    def update
      @purl = begin
                Purl.find_or_create_by(druid: druid_param)
              rescue ActiveRecord::RecordNotUnique
                retry
              end

      Racecar.produce_sync(value: cocina_object.to_json, key: druid_param, topic: "purl-updates")

      render json: true, status: :accepted
    end

    def destroy
      Purl.mark_deleted(druid_param)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

      def cocina_object
        # TODO: Remove the :created, :modified, :lock exclusions when
        # https://github.com/sul-dlss/cocina-models/commit/5d97fbd1e65554a8870a14449776ed68c3d5eb26 is released
        Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format, :created, :modified, :lock).to_unsafe_h)
      end
  end
end
