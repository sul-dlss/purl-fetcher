FactoryBot.define do
  factory :purl do
    sequence :druid do |n|
      "druid:zz#{format('%03d', n)}yy0000"
    end
    published_at { 1.day.ago }
    public_json { association :public_json, purl: instance }

    trait :with_release_tags do
      release_tags { [association(:release_tag, purl: instance), association(:release_tag, :sitemap, purl: instance)] }
    end

    trait :with_collection do
      collections { [association(:collection)] }
    end
  end
end
