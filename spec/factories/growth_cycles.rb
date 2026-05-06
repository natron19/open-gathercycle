FactoryBot.define do
  factory :growth_cycle do
    association :user
    organization_name    { "Test Community Club" }
    name                 { "Q2 2026 Membership Drive" }
    time_period          { "Q2 2026" }
    goal_description     { "Grow active membership by 30% in 90 days" }
    audience_description { "Local enthusiasts, mix of experience levels, active on social media." }
    status               { "pending" }
    gemini_raw           { nil }

    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :with_tasks do
      after(:create) do |cycle|
        %w[awareness engagement consolidation].each do |phase|
          3.times do |i|
            create(:cycle_task, growth_cycle: cycle, phase: phase, position: i)
          end
        end
      end
    end
  end
end
