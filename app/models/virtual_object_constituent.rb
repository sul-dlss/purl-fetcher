class VirtualObjectConstituent < ApplicationRecord
  default_scope { order(ordinal: :asc) }
  belongs_to :purl
end
