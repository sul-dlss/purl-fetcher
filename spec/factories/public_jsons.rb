FactoryBot.define do
  factory :public_json do
    data { Cocina::RSpec::Factories.build(:dro_with_metadata).to_json }
  end
end
