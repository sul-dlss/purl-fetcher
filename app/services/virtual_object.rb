# frozen_string_literal: true

# Service for finding virtual object membership
class VirtualObject
  # Find virtual objects that this item is a constituent of
  # @param [String] druid
  # @return [Array<Hash>] a list of results with ids and titles
  def self.for(druid:)
    purl = Purl.find_by(druid:)

    return [] unless purl

    purl.parents.map do |parent|
      {
        id: parent.druid,
        title: parent.title
      }
    end
  end
end
