class ApplicationController < ActionController::Base
  protect_from_forgery unless: -> { request.format.json? }, with: :exception

  rescue_from VersionedFilesService::Lock::LockError do |e|
    render build_error('423', e, 'Error acquiring lock')
  end

  private

  def page_params
    params.permit(:page)
  end

  def per_page_params
    params.permit(:per_page)
  end

  def druid_param
    return if params[:druid].blank?

    druid = params[:druid]
    druid = "druid:#{druid}" unless druid&.start_with?('druid:')
    druid
  end

  # JSON-API error response. See https://jsonapi.org/.
  def build_error(error_code, err, msg)
    {
      json: {
        errors: [
          {
            status: error_code,
            title: msg,
            detail: err.message
          }
        ]
      },
      content_type: 'application/json',
      status: error_code
    }
  end
end
