module V1
  class VersionsController < ApplicationController
    include Authenticated

    before_action :check_auth_token
    before_action :find_purl

    rescue_from VersionedFilesService::BadRequestError do |e|
      render build_error('400', e, 'Bad request')
    end

    def withdraw
      return render json: { error: "already deleted" }, status: :conflict if @purl.deleted?

      PurlAndStacksService.withdraw(purl: @purl, version: params[:version], withdrawn: params[:withdrawn])
    end

    private

    def find_purl
      @purl = Purl.find_by!(druid: druid_param)
    end
  end
end
