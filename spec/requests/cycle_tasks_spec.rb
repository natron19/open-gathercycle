require "rails_helper"

RSpec.describe "CycleTasks", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:cycle)      { create(:growth_cycle, user: user) }
  let(:task)       { create(:cycle_task, growth_cycle: cycle, completed: false) }

  def sign_in_as(u)
    post sign_in_path, params: { email: u.email, password: "password123" }
  end

  def toggle_path
    toggle_growth_cycle_cycle_task_path(cycle, task)
  end

  describe "PATCH toggle" do
    context "unauthenticated" do
      it "redirects to sign in" do
        patch toggle_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "authenticated as owner" do
      before { sign_in_as(user) }

      it "sets completed to true and returns turbo-stream content type" do
        patch toggle_path
        expect(task.reload.completed).to be true
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "toggles back to false on a second request" do
        patch toggle_path
        patch toggle_path
        expect(task.reload.completed).to be false
      end

      it "returns a turbo-stream element targeting dom_id(task) with no full HTML page" do
        patch toggle_path
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(task))
        expect(response.body).not_to include("<html")
      end
    end

    context "authenticated as a different user" do
      before { sign_in_as(other_user) }

      it "redirects (record not found) and does not modify the task" do
        patch toggle_path
        expect(response).to redirect_to(root_path)
        expect(task.reload.completed).to be false
      end
    end
  end

  describe "DELETE destroy" do
    def destroy_path
      growth_cycle_cycle_task_path(cycle, task)
    end

    context "unauthenticated" do
      it "redirects to sign in" do
        delete destroy_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "authenticated as owner" do
      before { sign_in_as(user) }

      it "destroys the task and returns a turbo-stream remove action" do
        task_id = task.id
        expect {
          delete destroy_path
        }.to change(CycleTask, :count).by(-1)

        expect(CycleTask.find_by(id: task_id)).to be_nil
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(task))
      end
    end

    context "authenticated as a different user" do
      before { sign_in_as(other_user) }

      it "redirects (record not found) and does not destroy the task" do
        task_id = task.id
        delete destroy_path
        expect(response).to redirect_to(root_path)
        expect(CycleTask.find_by(id: task_id)).to be_present
      end
    end
  end
end
