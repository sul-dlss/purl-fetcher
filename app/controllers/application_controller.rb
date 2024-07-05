class ApplicationController < ActionController::Base
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
