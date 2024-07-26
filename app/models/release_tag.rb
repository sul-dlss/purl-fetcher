class ReleaseTag < ApplicationRecord
  belongs_to :purl
  validates :name, uniqueness: { scope: :purl_id }
end
