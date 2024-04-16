FactoryBot.define do
  factory :release_tag do
    purl
    name { 'Searchworks' }
    release_type { true }

    trait :sitemap do
      name { 'PURL sitemap' }
    end
  end
end
