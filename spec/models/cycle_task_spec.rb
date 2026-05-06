require "rails_helper"

RSpec.describe CycleTask, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:effort_estimate) }
    it { is_expected.to validate_presence_of(:success_indicator) }

    it "is invalid with an unrecognised phase" do
      task = build(:cycle_task, phase: "kickoff")
      expect(task).not_to be_valid
      expect(task.errors[:phase]).to be_present
    end

    it "is valid with each allowed phase" do
      %w[awareness engagement consolidation].each do |p|
        expect(build(:cycle_task, phase: p)).to be_valid
      end
    end

    it "is invalid with an unrecognised owner_type" do
      task = build(:cycle_task, owner_type: "manager")
      expect(task).not_to be_valid
      expect(task.errors[:owner_type]).to be_present
    end

    it "is valid with each allowed owner_type" do
      %w[leader volunteer staff].each do |o|
        expect(build(:cycle_task, owner_type: o)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:growth_cycle) }
  end

  describe "defaults" do
    it "defaults completed to false" do
      task = build(:cycle_task)
      expect(task.completed).to be false
    end
  end
end
