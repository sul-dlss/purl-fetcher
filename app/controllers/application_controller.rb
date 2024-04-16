class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery unless: -> { request.format.json? }, with: :exception

  private

    def page_params
      params.permit(:page)
    end

    def per_page_params
      params.permit(:per_page)
    end

    def druid_param
      druid = params.require(:druid)
      druid = "druid:#{druid}" unless druid.start_with?('druid:')
      druid
    end
end
