class CycleTask < ApplicationRecord
  belongs_to :growth_cycle

  validates :title, :effort_estimate, :success_indicator, presence: true
  validates :phase,      inclusion: { in: %w[awareness engagement consolidation] }
  validates :owner_type, inclusion: { in: %w[leader volunteer staff] }
end
