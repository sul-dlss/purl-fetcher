class ReleaseTag < ApplicationRecord
  belongs_to :purl
  validates :name, uniqueness: { scope: :purl_id }

  ##
  # Locates an existing ReleaseTag record and sets the release_type as given
  #
  # @param [Purl] `purl`
  # @param [String] `name` release tag name
  # @param [Boolean] `release_type`
  # @return [ReleaseTag] finds or creates a ReleaseTag record for the given tuple
  def self.for(purl, name, release_type)
    tag = ReleaseTag.find_by(name:, purl_id: purl.id)
    if tag.present?
      tag.release_type = release_type
    else
      tag = ReleaseTag.create(name:, purl_id: purl.id, release_type:)
    end
    tag
  end
end
