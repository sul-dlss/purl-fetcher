FactoryBot.define do
  factory :purl do
    sequence :druid do |n|
      "druid:zz#{format('%03d', n)}yy0000"
    end
    published_at { 1.day.ago }
  end
end
