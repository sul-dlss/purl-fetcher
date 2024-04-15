module V1
  class DocsController < ApplicationController
    before_action :date_params

    def stats
      @metrics = Statistics.new
    end

    # API call to get a full list of all purls modified between two times
    def changes
      @changes = Purl.published
                     .status('public')
                     .where(updated_at: @first_modified..@last_modified)
                     .target(params[:target])
                     .includes(:collections, :release_tags)
                     .page(page_params[:page])
                     .per(per_page_params[:per_page])
    end

    # API call to get a full list of all purl deletes between two times
    def deletes
      @deletes = Purl.where(updated_at: @first_modified..@last_modified)
                     .status('deleted')
                     .target(params[:target])
                     .page(page_params[:page])
                     .per(per_page_params[:per_page])
    end

    private

      def date_params
        @first_modified = if params[:first_modified].present?
                            Time.zone.parse(params[:first_modified])
                          else
                            Time.zone.at(0)
                          end

        @last_modified = if params[:last_modified].present?
                           Time.zone.parse(params[:last_modified])
                         else
                           Time.zone.now
                         end
      end

      def per_page_params
        params.permit(:per_page)
      end
  end
end
