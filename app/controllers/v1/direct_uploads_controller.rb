module V1
  class DirectUploadsController < ActiveStorage::DirectUploadsController
    include Authenticated

    before_action :check_auth_token

    # The AS::DirectUploadsController has protect_from_forgery enabled. Since this is an API, we don't need that
    skip_forgery_protection
  end
end
