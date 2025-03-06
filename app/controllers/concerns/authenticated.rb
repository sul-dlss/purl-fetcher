module Authenticated
  extend ActiveSupport::Concern

  TOKEN_HEADER = 'Authorization'.freeze

  protected

  # Ensure a valid token is present, or renders "401: Not Authorized"
  def check_auth_token
    token = decoded_auth_token

    # Disabled in local dev
    return if Rails.env.development?

    return render json: { error: 'Not Authorized' }, status: :unauthorized unless token

    Honeybadger.context(invoked_by: token[:sub])
  end

  def decoded_auth_token
    @decoded_auth_token ||= begin
      body = JWT.decode(http_auth_header, Settings.hmac_secret, true, algorithm: 'HS256').first
      ActiveSupport::HashWithIndifferentAccess.new body
    rescue StandardError
      nil
    end
  end

  def http_auth_header
    return if request.headers[TOKEN_HEADER].blank?

    field = request.headers[TOKEN_HEADER]
    field.split.last
  end
end
