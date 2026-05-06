require "rails_helper"

STUB_PLAN = JSON.generate({
  "cycle_summary" => "A three-phase plan to grow membership.",
  "phases" => [
    { "phase" => "awareness", "label" => "Phase 1: Awareness", "objective" => "Expand visibility.",
      "tasks" => [
        { "title" => "Post on Facebook", "owner_type" => "volunteer",
          "effort_estimate" => "2 hours/week", "success_indicator" => "10 new followers" },
        { "title" => "Partner with local shops", "owner_type" => "leader",
          "effort_estimate" => "3 hours one-time", "success_indicator" => "Flyers at 2 shops" },
        { "title" => "Run a friend challenge", "owner_type" => "volunteer",
          "effort_estimate" => "1 hour/week", "success_indicator" => "15 non-members ride" }
      ]
    },
    { "phase" => "engagement", "label" => "Phase 2: Engagement", "objective" => "Convert prospects.",
      "tasks" => [
        { "title" => "Host a welcome event", "owner_type" => "leader",
          "effort_estimate" => "4 hours", "success_indicator" => "20 attendees" },
        { "title" => "Launch email welcome series", "owner_type" => "staff",
          "effort_estimate" => "3 hours one-time", "success_indicator" => "80% open rate" },
        { "title" => "Assign member buddies", "owner_type" => "volunteer",
          "effort_estimate" => "30 min/week", "success_indicator" => "All new members paired" }
      ]
    },
    { "phase" => "consolidation", "label" => "Phase 3: Consolidation", "objective" => "Retain members.",
      "tasks" => [
        { "title" => "Send retention survey", "owner_type" => "staff",
          "effort_estimate" => "2 hours", "success_indicator" => "80% response rate" },
        { "title" => "Launch ambassador program", "owner_type" => "leader",
          "effort_estimate" => "2 hours/month", "success_indicator" => "5 ambassadors active" },
        { "title" => "Celebrate milestone publicly", "owner_type" => "volunteer",
          "effort_estimate" => "1 hour", "success_indicator" => "Post published with 20+ engagements" }
      ]
    }
  ]
})

RSpec.describe "GrowthCycles", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let!(:cycle) { create(:growth_cycle, user: user) }

  let(:valid_params) do
    {
      growth_cycle: {
        organization_name:    "Riverside Cycling Club",
        name:                 "Q2 2026 Drive",
        time_period:          "Q2 2026",
        goal_description:     "Grow active membership by 30%",
        audience_description: "Local cycling enthusiasts aged 25-55"
      }
    }
  end

  def sign_in_as(u)
    post sign_in_path, params: { email: u.email, password: "password123" }
  end

  describe "GET /growth_cycles" do
    it "redirects unauthenticated users to sign in" do
      get growth_cycles_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 200 for authenticated users" do
      sign_in_as(user)
      get growth_cycles_path
      expect(response).to have_http_status(:ok)
    end

    it "includes the current user's cycle name" do
      sign_in_as(user)
      get growth_cycles_path
      expect(response.body).to include(cycle.name)
    end

    it "excludes other users' cycles" do
      other_cycle = create(:growth_cycle, user: other, name: "Other User Secret Cycle")
      sign_in_as(user)
      get growth_cycles_path
      expect(response.body).not_to include("Other User Secret Cycle")
    end
  end

  describe "GET /growth_cycles/new" do
    it "redirects unauthenticated users to sign in" do
      get new_growth_cycle_path
      expect(response).to redirect_to(sign_in_path)
    end

    it "returns 200 for authenticated users" do
      sign_in_as(user)
      get new_growth_cycle_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /growth_cycles/:id" do
    it "returns 200 for the owner" do
      sign_in_as(user)
      get growth_cycle_path(cycle)
      expect(response).to have_http_status(:ok)
    end

    it "redirects for a different user's cycle (record not found)" do
      other_cycle = create(:growth_cycle, user: other)
      sign_in_as(user)
      get growth_cycle_path(other_cycle)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /growth_cycles/:id/download" do
    let!(:task) { create(:cycle_task, growth_cycle: cycle, phase: "awareness", title: "Run a photo series") }

    it "redirects unauthenticated users to sign in" do
      get download_growth_cycle_path(cycle)
      expect(response).to redirect_to(sign_in_path)
    end

    context "authenticated as owner" do
      before { sign_in_as(user) }

      it "returns a file attachment with text/plain content type" do
        get download_growth_cycle_path(cycle)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/plain")
        expect(response.headers["Content-Disposition"]).to include("attachment")
      end

      it "includes the cycle name and task title in the markdown body" do
        get download_growth_cycle_path(cycle)
        expect(response.body).to include(cycle.name)
        expect(response.body).to include("Phase 1: Awareness")
        expect(response.body).to include(task.title)
      end

      it "marks completed tasks with [x] and incomplete with [ ]" do
        completed_task = create(:cycle_task, :completed, growth_cycle: cycle, phase: "engagement", title: "Done task")
        get download_growth_cycle_path(cycle)
        expect(response.body).to include("- [ ] **#{task.title}**")
        expect(response.body).to include("- [x] **#{completed_task.title}**")
      end
    end

    context "authenticated as a different user" do
      before { sign_in_as(other) }

      it "redirects (record not found)" do
        get download_growth_cycle_path(cycle)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /growth_cycles/:id" do
    it "destroys the cycle and its tasks and redirects" do
      cycle_with_tasks = create(:growth_cycle, :with_tasks, user: user)
      task_ids = cycle_with_tasks.cycle_tasks.pluck(:id)

      sign_in_as(user)
      delete growth_cycle_path(cycle_with_tasks)

      expect(response).to redirect_to(growth_cycles_path)
      expect(GrowthCycle.find_by(id: cycle_with_tasks.id)).to be_nil
      expect(CycleTask.where(id: task_ids)).to be_empty
    end
  end

  describe "POST /growth_cycles" do
    before { sign_in_as(user) }

    context "with a successful Gemini response" do
      before { gemini_returns(STUB_PLAN) }

      it "creates a GrowthCycle with tasks for each phase and redirects to show" do
        expect {
          post growth_cycles_path, params: valid_params
        }.to change(GrowthCycle, :count).by(1)

        expect(response.location).to match(%r{/growth_cycles/})
        new_cycle = GrowthCycle.find(response.location.split("/").last)
        expect(CycleTask.where(growth_cycle: new_cycle, phase: "awareness").count).to be >= 1
        expect(CycleTask.where(growth_cycle: new_cycle, phase: "engagement").count).to be >= 1
        expect(CycleTask.where(growth_cycle: new_cycle, phase: "consolidation").count).to be >= 1
      end
    end

    context "when Gemini raises GeminiError" do
      before { gemini_raises(GeminiService::GeminiError) }

      it "does not save a GrowthCycle and renders new with error content" do
        expect {
          post growth_cycles_path, params: valid_params
        }.not_to change(GrowthCycle, :count)

        expect(response.body).to include("Something went wrong")
      end
    end

    context "when Gemini raises TimeoutError" do
      before { gemini_raises(GeminiService::TimeoutError) }

      it "does not save a GrowthCycle and shows timeout message" do
        expect {
          post growth_cycles_path, params: valid_params
        }.not_to change(GrowthCycle, :count)

        expect(response.body).to include("took too long to respond")
      end
    end

    context "when Gemini returns malformed JSON" do
      before { gemini_returns("This is not JSON at all.") }

      it "does not save a GrowthCycle and shows a parse-failure message" do
        expect {
          post growth_cycles_path, params: valid_params
        }.not_to change(GrowthCycle, :count)

        expect(response.body).to include("unexpected format")
      end
    end

    context "GeminiService invocation" do
      it "calls GeminiService exactly once per create request" do
        expect(GeminiService).to receive(:generate).once.and_return(STUB_PLAN)
        post growth_cycles_path, params: valid_params
      end
    end
  end
end
