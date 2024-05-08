# frozen_string_literal: true

# Service for finding virtual object membership
class VirtualObject
  # Find virtual objects that this item is a constituent of
  # @param [String] druid
  # @return [Array<Hash>] a list of results with ids and titles
  def self.for(druid:)
    Purl.find_by(druid:).parents.map do |purl|
      {
        id: purl.druid,
        title: purl.title
      }
    end
  end
end
