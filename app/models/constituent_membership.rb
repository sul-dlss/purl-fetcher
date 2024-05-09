class ConstituentMembership < ApplicationRecord
  belongs_to :parent, class_name: 'Purl'
  belongs_to :child, class_name: 'Purl'
end
