FactoryBot.define do
  factory :release_tag do
    purl
    name { 'Searchworks' }
    release_type { true }
  end
end
