module V1
  class DocsController < ApplicationController
    def stats
      @metrics = Statistics.new
    end
  end
end
