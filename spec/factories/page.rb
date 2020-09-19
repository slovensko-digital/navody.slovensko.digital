FactoryBot.define do
  factory :page do
    sequence(:title) do |n|
      '%s %d' % [Faker::Commerce.product_name, n]
    end
    content { Faker::Lorem.paragraph(sentence_count: 10) }
    slug { title.parameterize }
    is_faq { false }
    sequence(:position) { |n| n }

    trait :faq do
      is_faq { true }
    end
  end
end
