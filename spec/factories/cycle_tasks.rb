FactoryBot.define do
  factory :cycle_task do
    association :growth_cycle
    phase             { "awareness" }
    title             { "Publish a member spotlight post series" }
    owner_type        { "volunteer" }
    effort_estimate   { "2 hours per week for 4 weeks" }
    success_indicator { "Four posts published with at least 10 shares each" }
    completed         { false }
    position          { 0 }

    trait :completed do
      completed { true }
    end

    trait :engagement do
      phase { "engagement" }
    end

    trait :consolidation do
      phase      { "consolidation" }
      owner_type { "staff" }
    end

    trait :leader do
      owner_type { "leader" }
    end
  end
end
