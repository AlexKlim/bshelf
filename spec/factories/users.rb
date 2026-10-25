FactoryBot.define do
  factory :user do
    sequence(:email) { "reader#{it}@example.com" }
    password { "password123" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end
  end
end
