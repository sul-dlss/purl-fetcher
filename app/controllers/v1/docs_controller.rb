module V1
  class DocsController < ApplicationController
    before_action :date_params

    def stats
      @metrics = Statistics.new
    end

    # API call to get a full list of all purls modified between two times
    # Used by content search via https://github.com/sul-dlss/purl_fetcher-client/blob/main/lib/purl_fetcher/client/reader.rb#L43-L51
    # and by the indexer https://github.com/sul-dlss/searchworks_traject_indexer/blob/64359399e8f670ed414b1c56c648dc9b95ad6bad/lib/traject/readers/purl_fetcher_reader.rb#L32-L40
    def changes
      @changes = Purl.published
                     .where(deleted_at: nil)
                     .where(updated_at: @first_modified..@last_modified)
                     .target('target' => params[:target])
                     .includes(:collections, :release_tags)
                     .page(page_params[:page])
                     .per(per_page_params[:per_page])
    end

    # API call to get a full list of all purl deletes between two times
    # Used by content search via https://github.com/sul-dlss/purl_fetcher-client/blob/main/lib/purl_fetcher/client/reader.rb#L43-L51
    # and by the indexer https://github.com/sul-dlss/searchworks_traject_indexer/blob/64359399e8f670ed414b1c56c648dc9b95ad6bad/lib/traject/readers/purl_fetcher_reader.rb#L32-L40
    def deletes
      @deletes = Purl.where(updated_at: @first_modified..@last_modified)
                     .where.not(deleted_at: nil)
                     .target('target' => params[:target])
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
