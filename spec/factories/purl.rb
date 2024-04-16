FactoryBot.define do
  factory :purl do
    sequence :druid do |n|
      "druid:zz#{n.to_s * 3}yy#{n.to_s * 4}"
    end
    published_at { 1.day.ago }
  end
end
