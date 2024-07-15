module V1
  class PurlsController < ApplicationController
    include Authenticated

    before_action :check_auth_token, only: :destroy
    before_action :find_purl, only: :destroy

    # Show the files that we have for this object. Used by DSA to know which files need to be shelved.
    def show
      # Causes a 404 for a deleted item, which might happen if a purl is deleted and then reused.
      purl = Purl.status('public').find_by!(druid: druid_param)
      render json: { files_by_md5: purl.public_json.files_by_md5 }
    end

    def destroy
      return render json: { error: "not yet published" }, status: :conflict if @purl.new_record?
      return render json: { error: "already deleted" }, status: :conflict if @purl.deleted?

      @purl.mark_deleted

      # TODO: Once DSA is providing the version, || '1' can be removed.
      PurlAndStacksService.delete(purl: @purl, version: params[:version] || '1')
      Racecar.produce_sync(value: nil, key: druid_param, topic: Settings.indexer_topic)
    end

    private

    def find_purl
      @purl = begin
        Purl.find_or_initialize_by(druid: druid_param)
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    end
  end
end
