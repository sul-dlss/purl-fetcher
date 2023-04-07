FactoryBot.define do
  factory :purl do
    sequence :druid do
      "druid:zz#{format('%03d', rand(1000))}yy#{format('%04d', rand(10_000))}"
    end
  end
end
