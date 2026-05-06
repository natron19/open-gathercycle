class GrowthCycle < ApplicationRecord
  belongs_to :user
  has_many :cycle_tasks, dependent: :destroy

  validates :organization_name, :name, :time_period, :goal_description,
            :audience_description, presence: true
  validates :status, inclusion: { in: %w[pending active completed] }
end
