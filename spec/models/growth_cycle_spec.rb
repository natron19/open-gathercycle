require "rails_helper"

RSpec.describe GrowthCycle, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:organization_name) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:time_period) }
    it { is_expected.to validate_presence_of(:goal_description) }
    it { is_expected.to validate_presence_of(:audience_description) }

    it "is invalid with an unrecognised status" do
      cycle = build(:growth_cycle, status: "unknown")
      expect(cycle).not_to be_valid
      expect(cycle.errors[:status]).to be_present
    end

    it "is valid with each allowed status" do
      %w[pending active completed].each do |s|
        expect(build(:growth_cycle, status: s)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:cycle_tasks).dependent(:destroy) }

    it "destroying a cycle destroys its tasks" do
      cycle = create(:growth_cycle, :with_tasks)
      expect { cycle.destroy }.to change(CycleTask, :count).by(-9)
    end
  end

  describe "cross-user scoping" do
    it "raises RecordNotFound when a different user queries by id" do
      owner = create(:user)
      other = create(:user)
      cycle = create(:growth_cycle, user: owner)

      expect {
        other.growth_cycles.find(cycle.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
