FactoryBot.define do
  factory :step do
    association :journey

    sequence(:title) do |n|
      '%s %d' % [Faker::Commerce.product_name, n]
    end
    keywords { Faker::Commerce.department(max: 5).gsub(/,/, '') }
    is_waiting_step { false }
    slug { title.parameterize }
    description { Faker::Lorem.paragraph(sentence_count: 5) }
    sequence(:position) { |n| n }
  end
end
