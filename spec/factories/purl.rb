FactoryBot.define do
  factory :purl do
    sequence :druid do |n|
      "druid:zz#{format('%03d', n)}yy0000"
    end
    published_at { 1.day.ago }
    public_json { association :public_json, purl: instance }
  end
end
