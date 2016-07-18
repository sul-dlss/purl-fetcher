require 'rsolr'
require 'json'

class ApplicationController < ActionController::Base
  include Fetcher

  before_action :clean_date_params

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  protected

    def clean_date_params
      # if user decides they only want registered objects, it is not possible to further qualify with dates, since the date solr field we look at comes from publication (i.e. after accessioning)
      if registered_only?(params)
        params.delete(:first_modified)
        params.delete(:last_modified)
      end
    end

    def render_result(result)
      respond_to do |format|
        format.json { render json: result.to_json }
        format.xml { render json: result.to_xml(root: 'results') }
      end
    end
end
