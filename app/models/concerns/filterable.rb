module Filterable
  extend ActiveSupport::Concern

  module ClassMethods
    ##
    # @param [Hash] filtering_params
    def filter(filtering_params)
      results = where(nil)
      filtering_params.each do |key, value|
        results = results.public_send(key, value) if value.present?
      end
      results
    end
  end
end