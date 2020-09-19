FactoryBot.define do
  factory :user_task do
    association :task
    association :user_step
  end
end
