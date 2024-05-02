module V1
  class PurlsController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: %i[update destroy]

    # Show the public json for the object. Used by purl to know if this object should be indexed by crawlers.
    def show
      purl = Purl.find_by(druid: druid_param)
      render json: purl.as_public_json
    end

    ##
    # Update the database purl record from the passed in cocina
    def update
      # We can't store 4 byte UTF-8 characters in the database yet, so prevent errors and tell the sender.
      return render(plain: '4 byte UTF-8 characters are not acceptable.', status: :unprocessable_entity) if title_has_utf8mb4?

      @purl = begin
                Purl.find_or_create_by(druid: druid_param)
              rescue ActiveRecord::RecordNotUnique
                retry
              end

      # Get the actions from the release tags on the cocina model. In the near future,
      # the releaseTags will be removed from Cocina.
      actions = { index: [], delete: [] }.tap do |releases|
        cocina_object.administrative.releaseTags.each do |tag|
            releases[tag.release ? :index : :delete] << tag.to
        end
      end

      Racecar.produce_sync(value: { cocina: cocina_object, actions: }.to_json, key: druid_param, topic: "purl-updates")

      render json: true, status: :accepted
    end

    def destroy
      Purl.mark_deleted(druid_param)
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

    def title_has_utf8mb4?
      params[:description][:title].to_s.match?(/[\u{10000}-\u{10FFFF}]/)
    end

    def cocina_object
      Cocina::Models.build(params.except(:action, :controller, :druid, :purl, :format).to_unsafe_h)
    end
  end
end
