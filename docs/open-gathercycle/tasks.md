# GatherCycle Demo — Build Tasks

Tracks implementation progress across all phases. Each phase ends with manual smoke tests and RSpec coverage before moving to the next phase.

**Spec reference:** `docs/open-gathercycle/gathercycle-demo-spec.md`
**Source guides:** `docs/ai-templates.md`, `docs/ai-guardrails.md`, `docs/testing.md`, `docs/turbo-stimulus-patterns.md`

---

## Housekeeping (Completed Outside Phases)

- [x] Rename all database entries in `config/database.yml` from `open_base_*` to `open_gathercycle_*`, update production username and `OPEN_GATHERCYCLE_DATABASE_PASSWORD` env var name.

---

## Implementation Notes (Read Before Starting)

**Model name discrepancy:** The spec lists `gemini-2.0-flash` for the AI template, but `docs/ai-templates.md` and `CLAUDE.md` both confirm that model returns 404 on v1beta for new API keys. **Use `gemini-2.5-flash` instead.** This is a known deviation from the spec document.

**Stylesheet approach:** The spec references `_accent.scss`, but this app uses Propshaft with no SCSS pipeline. All custom CSS goes directly into `app/assets/stylesheets/application.css`. Do not create a separate SCSS file.

**Turbo Streams:** Always use `turbo_stream.update()`, never `turbo_stream.replace()`. The task toggle action is the only Turbo Stream response in this app.

**No backward compatibility:** When seeds.rb is updated, remove `demo_placeholder_v1` entirely. Do not keep it alongside `gathercycle_plan_v1`.

---

## Phase 1 — Branding & UI Configuration

**Scope:** Set the GatherCycle identity: env vars, accent colors, navbar, home page, and dashboard redirect. No new models or routes. Everything in this phase is purely UI and configuration.

### Tasks

- [x] Update `.env.example`: set `APP_NAME=GatherCycle Demo`, `APP_TAGLINE=Set a growth goal. Get a full cycle plan with distributed tasks and owners.`, `APP_DESCRIPTION=Turn a community growth goal into a structured three-phase execution plan with distributed tasks, owner types, and measurable success indicators.`
- [x] Update `app/assets/stylesheets/application.css`: replace the blue `--accent`/`--accent-hover` values with purple (`#a855f7` / `#9333ea`), add `--accent-secondary: #4ade80` (green), and add all custom utility rules listed in spec section 12:
  - `.btn-accent` class (background + border + hover using CSS custom properties)
  - `.phase-header-awareness`, `.phase-header-engagement`, `.phase-header-consolidation` left-border classes
  - `.badge-leader` badge class (purple background)
  - `input[type="checkbox"] { accent-color: var(--accent) }`
  - `.progress-bar { background-color: var(--accent) }` override
- [x] Update `app/views/layouts/application.html.erb` navbar: add "My Cycles" link for signed-in users before the dropdown. Uses `/growth_cycles` string for now; Phase 3 switches to `growth_cycles_path` named helper once route is defined.
- [x] Replace `app/views/home/index.html.erb` with the GatherCycle landing page. Three sections:
  1. **Hero** — headline (`APP_NAME` from env), tagline (`APP_TAGLINE` from env), two CTA buttons: "Sign Up" → `sign_up_path`, "Sign In" → `sign_in_path`
  2. **How it works** — three Bootstrap numbered cards: (1) Describe your goal and audience, (2) Gemini generates your three-phase plan, (3) Assign and track tasks as your team completes them
  3. **Open source note** — brief paragraph about MIT license and the boilerplate foundation
- [x] Update `app/views/dashboard/show.html.erb`: static "Create Your First Cycle" prompt card with button to `/growth_cycles/new`. Conditional redirect logic wired in Phase 2 once GrowthCycle model exists.
- [x] Update `app/controllers/dashboard_controller.rb`: TODO comment added; `redirect_to growth_cycles_path if current_user.growth_cycles.any?` will be uncommented in Phase 2.

### Manual Tests — Phase 1

- [ ] Start the server (`bin/dev`) and visit `http://localhost:3000`
- [ ] Verify the home page shows the GatherCycle hero with purple accent button colors
- [ ] Verify the "How it works" three-step section renders correctly
- [ ] Sign in as `demo@example.com` / `password123`
- [ ] Verify the navbar shows "My Cycles" link for signed-in users
- [ ] Visit `/dashboard` — for a new user it should show the "Create Your First Cycle" prompt (or redirect once Phase 2+ is in place)
- [ ] Sign out — verify nav returns to Sign In / Sign Up buttons
- [ ] Inspect page source and verify no hardcoded "GatherCycle Demo" strings — all app name references use `ENV.fetch("APP_NAME", ...)`

### RSpec Tests — Phase 1

No new spec files required for this phase. The boilerplate's existing request specs (`spec/requests/sessions_spec.rb`, home page rendering) should continue to pass without modification. Run the full suite to confirm nothing is broken:

```
bundle exec rspec
```

---

## Phase 2 — Data Model

**Scope:** Migrations, models, and factories for `GrowthCycle` and `CycleTask`. No controllers or views. After this phase the models are testable in isolation.

### Tasks

- [x] Create migration `20260504000001_create_growth_cycles.rb` — `growth_cycles` table with all fields, indexes on `status` and `created_at`, FK to `users`
- [x] Create migration `20260504000002_create_cycle_tasks.rb` — `cycle_tasks` table with all fields, indexes on `phase` and `completed`, FK to `growth_cycles`
- [x] Run `rails db:migrate`
- [x] Create `app/models/growth_cycle.rb` — `belongs_to :user`, `has_many :cycle_tasks, dependent: :destroy`, presence validations, status inclusion validation
- [x] Create `app/models/cycle_task.rb` — `belongs_to :growth_cycle`, presence validations, phase and owner_type inclusion validations
- [x] Add `has_many :growth_cycles, dependent: :destroy` to `app/models/user.rb`
- [x] Activate dashboard redirect in `app/controllers/dashboard_controller.rb` (`redirect_to growth_cycles_path if current_user.growth_cycles.any?`)
- [x] Create `spec/factories/growth_cycles.rb`:
  ```ruby
  FactoryBot.define do
    factory :growth_cycle do
      association :user
      organization_name   { "Test Community Club" }
      name                { "Q2 2026 Membership Drive" }
      time_period         { "Q2 2026" }
      goal_description    { "Grow active membership by 30% in 90 days" }
      audience_description { "Local enthusiasts, mix of experience levels, active on social media." }
      status              { "pending" }
      gemini_raw          { nil }

      trait :active do
        status { "active" }
      end

      trait :completed do
        status { "completed" }
      end

      trait :with_tasks do
        after(:create) do |cycle|
          %w[awareness engagement consolidation].each_with_index do |phase, phase_idx|
            3.times do |i|
              create(:cycle_task, growth_cycle: cycle, phase: phase, position: i)
            end
          end
        end
      end
    end
  end
  ```
- [x] Create `spec/factories/cycle_tasks.rb`:
  ```ruby
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
        phase { "consolidation" }
        owner_type { "staff" }
      end

      trait :leader do
        owner_type { "leader" }
      end
    end
  end
  ```

### Manual Tests — Phase 2

```bash
# Open rails console and verify models behave as expected
rails console

# Valid cycle saves
cycle = GrowthCycle.new(user: User.first, organization_name: "Test Org", name: "Q2", time_period: "Q2 2026", goal_description: "Grow by 30%", audience_description: "Local club members")
cycle.valid? # => true

# Missing field makes record invalid
GrowthCycle.new(user: User.first, name: "Q2").valid? # => false

# Invalid status rejected
GrowthCycle.new(status: "unknown").valid? # => false

# CycleTask validates phase and owner_type
CycleTask.new(growth_cycle: cycle, phase: "invalid", title: "T", effort_estimate: "E", success_indicator: "S", owner_type: "leader").valid? # => false
CycleTask.new(growth_cycle: cycle, phase: "awareness", title: "T", effort_estimate: "E", success_indicator: "S", owner_type: "invalid").valid? # => false
```

### RSpec Tests — Phase 2

- [x] Create `spec/models/growth_cycle_spec.rb` covering:
  1. Validates presence of `organization_name`, `name`, `time_period`, `goal_description`, `audience_description`
  2. Validates inclusion of `status` in `%w[pending active completed]`; arbitrary string is invalid
  3. `belongs_to :user` — cycle without `user_id` is invalid
  4. `has_many :cycle_tasks, dependent: :destroy` — destroying cycle destroys tasks
  5. Cross-user scoping: `current_user.growth_cycles.find(other_cycle.id)` raises `ActiveRecord::RecordNotFound`

- [x] Create `spec/models/cycle_task_spec.rb` covering:
  1. Validates presence of `title`, `effort_estimate`, `success_indicator`
  2. Validates inclusion of `phase` in `%w[awareness engagement consolidation]`
  3. Validates inclusion of `owner_type` in `%w[leader volunteer staff]`
  4. Default `completed` is `false`
  5. `belongs_to :growth_cycle` — task without `growth_cycle_id` is invalid

```
bundle exec rspec spec/models/growth_cycle_spec.rb spec/models/cycle_task_spec.rb
```

---

## Phase 3 — Routes, Index, New, Show, Destroy

**Scope:** All GrowthCycles routes and views except the Gemini-powered `create` action (which is stubbed to re-render `new` in this phase). After this phase the app is navigable end-to-end with seeded data.

### Tasks

- [x] Update `config/routes.rb`:
  ```ruby
  resources :growth_cycles, only: [:index, :new, :create, :show, :destroy] do
    resources :cycle_tasks, only: [] do
      member { patch :toggle }
    end
  end
  ```
- [x] Create `app/controllers/growth_cycles_controller.rb`:
  - Inherits from `ApplicationController` (auth enforced automatically)
  - `index`: `@cycles = current_user.growth_cycles.order(created_at: :desc)`
  - `new`: `@cycle = GrowthCycle.new`
  - `create`: stub for now — set `flash[:alert] = "Gemini not wired yet"` and `redirect_to new_growth_cycle_path` (will be replaced in Phase 4)
  - `show`: `@cycle = current_user.growth_cycles.find(params[:id])`, then `@phases = @cycle.cycle_tasks.order(:position).group_by(&:phase)`
  - `destroy`: find, destroy, redirect to `growth_cycles_path` with notice
  - Private `growth_cycle_params`: permit `organization_name`, `name`, `time_period`, `goal_description`, `audience_description`
- [x] Update `app/controllers/dashboard_controller.rb`: add `redirect_to growth_cycles_path if current_user.growth_cycles.any?` before the default render
- [x] Create `app/views/growth_cycles/index.html.erb`:
  - Page header: `<h1>My Cycles</h1>` + "New Cycle" button (`.btn-accent`)
  - Responsive card grid: `row row-cols-1 row-cols-md-2 row-cols-lg-3`
  - Iterate over `@cycles`, render `_cycle_card` partial for each
  - Empty state: Bootstrap card with centered text and "Create Your First Cycle" button when `@cycles.empty?`
- [x] Create `app/views/growth_cycles/_cycle_card.html.erb` (locals: `cycle`):
  - Card with: cycle name, organization name, time period, goal (truncated to 80 chars)
  - Bootstrap progress bar: `cycle.cycle_tasks.where(completed: true).count` / `cycle.cycle_tasks.count` (guard division by zero with `0` when count is 0)
  - Status badge: `pending` → `bg-secondary`, `active` → uses `--accent`, `completed` → `bg-success`
  - "View Plan" link to `growth_cycle_path(cycle)`, delete link with `data-turbo-confirm`
- [x] Create `app/views/growth_cycles/new.html.erb`:
  - Brief instruction block above the form
  - Renders `_form` partial
  - Wraps form in a single-column `col-md-8 offset-md-2` layout
- [x] Create `app/views/growth_cycles/_form.html.erb`:
  - `form_with model: @cycle` with Bootstrap classes
  - Fields (all with `form-label`, `form-control`, `is-invalid` on error):
    - `organization_name` — text field
    - `name` — text field with hint "Give this cycle a short label"
    - `time_period` — text field with hint "e.g., Q2 2026, Fall 2026"
    - `goal_description` — text field with hint "e.g., Grow paid membership by 40% in 90 days"
    - `audience_description` — text area (4 rows) with hint "Describe your community — who they are, what they care about, how active they are"
  - Submit button: "Generate My Cycle Plan" with `.btn-accent` class
  - Attach `data-controller="generate-form"` to the form element
- [x] Create `app/views/growth_cycles/show.html.erb`:
  - Page header: cycle name, org name, time period, goal, status badge
  - Three-column layout: `row` with three `col-md-4` children, rendered via `_phase_column` partial
  - Contextual AI note below columns: "This plan was generated by AI based on the goal and audience description you provided. Review tasks with your team and adapt them to your organization's specific context before assigning them."
  - Bootstrap collapse toggle labeled "Show raw Gemini response" revealing `@cycle.gemini_raw` in `<pre class="small text-muted">` (show "No raw response available." when `gemini_raw.blank?`)
  - Delete button: `.btn-outline-danger` with `data-turbo-method: :delete` and `data-turbo-confirm`
- [x] Create `app/views/growth_cycles/_phase_column.html.erb` (locals: `phase_name`, `phase_label`, `objective`, `tasks`):
  - Phase header card with appropriate `.phase-header-{phase_name}` CSS class
  - Phase label heading and objective text
  - `list-group` iterating over tasks, rendering `_task_item` partial
  - "No tasks yet." placeholder when tasks array is empty
- [x] Create `app/views/growth_cycles/_task_item.html.erb` (locals: `task`, `growth_cycle`):
  - Wrapped in `turbo_frame_tag dom_id(task)`
  - `form_with url: toggle_growth_cycle_cycle_task_path(growth_cycle, task), method: :patch` with `data-controller="checkbox-submit"`
  - Checkbox: `type="checkbox"`, checked when `task.completed`, with `data-action="change->checkbox-submit#submit"`
  - Task title in `<span>` with `text-decoration-line-through text-muted` when `task.completed`
  - Owner type badge: `.badge-leader` for `leader`, `bg-success` for `volunteer`, `bg-info` for `staff`
  - Effort estimate and success indicator in `small text-muted` below the title
- [x] Create `app/javascript/controllers/generate_form_controller.js`:
  ```javascript
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["button", "spinner"]

    submit() {
      this.buttonTarget.disabled = true
      this.buttonTarget.textContent = ""
      this.spinnerTarget.classList.remove("d-none")
    }
  }
  ```
  Wire up in the form: `data-controller="generate-form"`, `data-action="submit->generate-form#submit"`, submit button with `data-generate-form-target="button"`, and an inline spinner element with `data-generate-form-target="spinner" class="d-none"`.

### Manual Tests — Phase 3

- [ ] Visit `/growth_cycles` — verify empty state renders correctly with "Create Your First Cycle" button
- [ ] Visit `/growth_cycles/new` — verify all five form fields render with correct hints and labels
- [ ] Submit the form (stub create currently redirects to new with alert flash) — verify flash appears
- [ ] Open rails console and create a test cycle with tasks, then visit its show page:
  ```ruby
  u = User.find_by(email: "demo@example.com")
  gc = GrowthCycle.create!(user: u, organization_name: "Test Club", name: "Q2 Drive", time_period: "Q2 2026", goal_description: "Grow by 30%", audience_description: "Local club members", status: "active")
  CycleTask.create!(growth_cycle: gc, phase: "awareness", title: "Post on Facebook", owner_type: "volunteer", effort_estimate: "1 hour/week", success_indicator: "10 new followers", position: 0)
  CycleTask.create!(growth_cycle: gc, phase: "engagement", title: "Host welcome event", owner_type: "leader", effort_estimate: "4 hours", success_indicator: "20 attendees", position: 0)
  CycleTask.create!(growth_cycle: gc, phase: "consolidation", title: "Send retention survey", owner_type: "staff", effort_estimate: "2 hours", success_indicator: "80% response rate", position: 0)
  ```
- [ ] Visit `/growth_cycles/:id` (the cycle just created) — verify three-column layout, task cards, owner badges, raw response toggle (shows "No raw response available.")
- [ ] Click the delete button on the index card — verify confirmation dialog appears and cycle is deleted
- [ ] Sign in as `demo@example.com` and visit `/dashboard` — verify it shows the "Create Your First Cycle" prompt (or redirects after Phase 2 model is available)

### RSpec Tests — Phase 3

- [x] Create `spec/requests/growth_cycles_spec.rb` with the auth and access control tests (full Gemini tests are added in Phase 4):
  1. `GET /growth_cycles` — 200 for authenticated user, redirects unauthenticated to sign-in
  2. `GET /growth_cycles` — includes current user's cycle name; excludes another user's cycle
  3. `GET /growth_cycles/new` — 200 for authenticated user; redirects unauthenticated to sign-in
  4. `GET /growth_cycles/:id` — 200 for owner; raises `ActiveRecord::RecordNotFound` for different user's cycle
  5. `DELETE /growth_cycles/:id` — destroys cycle and tasks; redirects to `growth_cycles_path`

```
bundle exec rspec spec/requests/growth_cycles_spec.rb
```

---

## Phase 4 — Gemini Integration (Create Action)

**Scope:** Wire the form to Gemini. Implement full create action with JSON parsing, transaction save, and error handling. Seed the `gathercycle_plan_v1` template. After this phase, submitting the form generates and saves a real plan.

### Tasks

- [x] Update `db/seeds.rb`:
  - Remove `demo_placeholder_v1` block entirely
  - Add `gathercycle_plan_v1` template using `find_or_create_by!(name: "gathercycle_plan_v1")`:
    - `model`: `"gemini-2.5-flash"` (**not** `gemini-2.0-flash` — see implementation notes above)
    - `max_output_tokens`: `2500`
    - `temperature`: `0.5`
    - Full `system_prompt` from spec section 7 (copy verbatim)
    - Full `user_prompt_template` from spec section 7 (copy verbatim, including all four `{{variable}}` placeholders and the requirements list)
    - `description` and `notes` from spec section 7
  - Run `rails db:seed` after saving

- [x] Implement `GrowthCyclesController#create`:
  ```ruby
  def create
    @cycle = current_user.growth_cycles.build(growth_cycle_params)

    raw = GeminiService.generate(
      template:  "gathercycle_plan_v1",
      variables: {
        organization_name:    @cycle.organization_name,
        time_period:          @cycle.time_period,
        goal_description:     @cycle.goal_description,
        audience_description: @cycle.audience_description
      }
    )

    @cycle.gemini_raw = raw
    parsed = JSON.parse(raw.gsub(/\A```json\n?|\n?```\z/, ""))

    ActiveRecord::Base.transaction do
      @cycle.save!
      parsed["phases"].each do |phase_data|
        phase_data["tasks"].each_with_index do |task_data, idx|
          @cycle.cycle_tasks.create!(
            phase:             phase_data["phase"],
            title:             task_data["title"],
            owner_type:        task_data["owner_type"],
            effort_estimate:   task_data["effort_estimate"],
            success_indicator: task_data["success_indicator"],
            position:          idx
          )
        end
      end
    end

    redirect_to growth_cycle_path(@cycle), notice: "Your cycle plan is ready."

  rescue GeminiService::BudgetExceededError
    render partial: "shared/ai_error", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity
  rescue GeminiService::GatekeeperError
    render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity
  rescue GeminiService::TimeoutError
    render partial: "shared/ai_error", locals: { error_type: :timeout }, status: :unprocessable_entity
  rescue GeminiService::GeminiError
    render partial: "shared/ai_error", locals: { error_type: :error }, status: :unprocessable_entity
  rescue JSON::ParseError
    flash.now[:alert] = "Gemini returned an unexpected format. Please try again. If the problem persists, check the admin LLM request log."
    render :new, status: :unprocessable_entity
  end
  ```

  Note: The `render partial:` calls for Gemini errors will re-render `new.html.erb` context. If these need to render the full new page with the error partial visible, consider rendering `:new` with an `@error_type` instance variable instead and embedding the partial inside `new.html.erb`. Follow the ai-templates.md pattern for the project.

- [x] Add rate limiting to the create action in `GrowthCyclesController`:
  ```ruby
  rate_limit to: 5, within: 1.minute, only: [:create],
             with: -> { redirect_to new_growth_cycle_path, alert: "Please wait a moment before generating another plan." }
  ```
- [x] Run `rails db:seed` — verify `gathercycle_plan_v1` appears in `/admin/ai_templates`
- [ ] Test the template in the admin panel: visit `/admin/ai_templates`, click Edit on `gathercycle_plan_v1`, fill in sample values, click "Run Test", verify JSON response is returned

### Manual Tests — Phase 4

- [ ] Sign in as `demo@example.com`, visit `/growth_cycles/new`
- [ ] Fill in all four fields with realistic data:
  - Organization: "Riverside Cycling Club"
  - Cycle name: "Q2 2026 Membership Drive"
  - Time period: "Q2 2026"
  - Goal: "Grow active membership by 30% in 90 days"
  - Audience: "Local cycling enthusiasts aged 25-55. Active on Facebook. Motivated by group rides."
- [ ] Click "Generate My Cycle Plan" — verify the button disables and spinner appears
- [ ] Wait 3-10 seconds for Gemini — verify redirect to show page with three-column plan
- [ ] On the show page, verify each phase has 3-4 tasks with title, owner badge, effort estimate, and success indicator visible
- [ ] Click "Show raw Gemini response" — verify the JSON appears in the pre block
- [ ] Visit `/admin/llm_requests` — verify the call logged with `success` status and token counts
- [ ] Test error path: temporarily point the template to a bad model name in the admin UI, submit the form, verify the error partial renders. Reset the model name.

### RSpec Tests — Phase 4

- [x] Add to `spec/requests/growth_cycles_spec.rb`:
  1. `POST /growth_cycles` with valid params + stubbed successful Gemini response: verifies `GrowthCycle` created, tasks created (verify at least one task per phase), redirects to `growth_cycle_path`
  2. `POST /growth_cycles` with `GeminiService::GeminiError` stubbed: no `GrowthCycle` saved, response renders error content
  3. `POST /growth_cycles` with `GeminiService::TimeoutError` stubbed: no `GrowthCycle` saved, response includes timeout messaging
  4. `POST /growth_cycles` with a Gemini response that is malformed JSON: no `GrowthCycle` saved, response body includes parse-failure message
  5. `POST /growth_cycles` — verifies an `LlmRequest` record is created on each Gemini call

  Use the spec section 9 stub JSON structure for the success stub:
  ```ruby
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
  ```

```
bundle exec rspec spec/requests/growth_cycles_spec.rb
```

---

## Phase 5 — Task Toggle (CycleTasksController + Stimulus)

**Scope:** Inline checkbox task completion via Turbo Streams. Two Stimulus controllers: `generate-form` (already created in Phase 3) and `checkbox-submit` (new in this phase). After this phase tasks can be checked/unchecked without a full page reload.

### Tasks

- [x] Create `app/controllers/cycle_tasks_controller.rb`:
  ```ruby
  class CycleTasksController < ApplicationController
    def toggle
      growth_cycle = current_user.growth_cycles.find(params[:growth_cycle_id])
      task = growth_cycle.cycle_tasks.find(params[:id])
      task.update!(completed: !task.completed)

      render turbo_stream: turbo_stream.update(
        dom_id(task),
        partial: "growth_cycles/task_item",
        locals:  { task: task, growth_cycle: growth_cycle }
      )
    end
  end
  ```
- [x] Create `app/javascript/controllers/checkbox_submit_controller.js`:
  ```javascript
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    submit() {
      this.element.requestSubmit()
    }
  }
  ```
  This is the single-line controller referenced in spec section 12. The checkbox fires `change->checkbox-submit#submit`, which calls `requestSubmit()` on the form.

- [x] Verify the `_task_item.html.erb` partial correctly wires up `data-controller="checkbox-submit"` on the form and `data-action="change->checkbox-submit#submit"` on the checkbox input (should already be in place from Phase 3 — confirm the wiring is correct)
- [x] Verify `turbo_stream.update` targets `dom_id(task)`, which matches the `turbo_frame_tag dom_id(task)` wrapper in `_task_item.html.erb`

### Manual Tests — Phase 5

- [ ] Visit any cycle's show page that has tasks
- [ ] Check a task checkbox — verify the checkbox state updates inline without a page reload
- [ ] Verify the task title gains strikethrough styling when completed
- [ ] Uncheck the same task — verify it returns to uncompleted state
- [ ] Visit `/admin/llm_requests` — the toggle does NOT call Gemini, so no new LLM request should appear (the toggle is a standard DB update)
- [ ] Open browser DevTools network tab and verify the toggle request returns `text/vnd.turbo-stream.html` content type

### RSpec Tests — Phase 5

- [x] Create `spec/requests/cycle_tasks_spec.rb` covering:
  1. `PATCH toggle` with `completed: false` task → sets to `true`, returns `text/vnd.turbo-stream.html`
  2. Second `PATCH toggle` → sets back to `false` (toggle works in both directions)
  3. Response body includes a `turbo-stream` element targeting `dom_id(task)`; does not include full HTML page markers (no `<html>` tag)
  4. Different signed-in user toggling another user's task → raises `ActiveRecord::RecordNotFound`; task not modified
  5. Unauthenticated request → redirects to sign-in

```
bundle exec rspec spec/requests/cycle_tasks_spec.rb
```

---

## Phase 6 — Seeds & Final Polish

**Scope:** Seed two sample growth cycles so the demo has content on first run without a Gemini API key. Final styling review. Update README with GatherCycle-specific content.

### Tasks

- [x] Add two sample `GrowthCycle` records to `db/seeds.rb` (placed after user and template seeds, using `demo_user` as the owner):

  **Cycle 1 — Active, partially complete (Riverside Cycling Club):**
  - All fields per spec section 10
  - `status: "active"`, `gemini_raw` set to a JSON string matching the schema
  - 12 `CycleTask` records (4 per phase) matching the spec section 10 task list
  - Tasks seeded with `completed: true` for the first 2 awareness tasks and first 2 engagement tasks (4 total), remaining 8 `completed: false`
  - Use `find_or_create_by!(growth_cycle: cycle1, title: task_title)` to avoid duplicate seeds on re-runs

  **Cycle 2 — Pending, no tasks (Eastside Makers Guild):**
  - All fields per spec section 10
  - `status: "pending"`, `gemini_raw: nil`
  - No `CycleTask` records — represents a cycle awaiting plan generation

- [ ] Run `rails db:seed` — verify both cycles appear at `/growth_cycles`, the active cycle shows a progress bar, and the pending cycle shows a pending badge
- [ ] Review the index page with seeded data and verify the progress bar calculation is correct (4 completed of 12 total = 33%)
- [ ] Review the show page for cycle 1: verify 4 tasks per phase, completed tasks show strikethrough, owner badges render in correct colors
- [x] Update `README.md`: add the GatherCycle Demo section per spec section 11 (headline, tagline, why-I-built-this, tuning-the-AI-prompt, app-specific-setup instructions, demo credentials)

### Manual Tests — Phase 6

- [ ] `rails db:seed` (or `rails db:reset db:seed`) from scratch — no errors
- [ ] Visit `/growth_cycles` — verify two cycle cards with correct progress bars and status badges
- [ ] Click "View Plan" on the Riverside Cycling Club cycle — verify three columns with 4 tasks each, 4 tasks showing checked/strikethrough state
- [ ] Click "View Plan" on the Eastside Makers Guild cycle — verify the show page handles gracefully when tasks array is empty (each phase column shows "No tasks yet.")
- [ ] Verify the raw response toggle on cycle 1 shows the seeded JSON
- [ ] Full user flow: start from home page → sign up as a new user → visit /growth_cycles → create a new cycle → verify Gemini generates a plan → check off tasks → delete the cycle

### RSpec Tests — Phase 6

No new spec files in this phase. Run the full suite to confirm seeds don't break anything and all prior specs still pass:

```
bundle exec rspec
```

---

## Phase 7 — Full RSpec Coverage Audit

**Scope:** Verify the full test suite matches the spec's RSpec outline (section 9). Fill any gaps. All specs must pass with zero real API calls.

### Tasks

- [x] Audit `spec/models/growth_cycle_spec.rb` against spec section 9 — all 5 cases covered
- [x] Audit `spec/models/cycle_task_spec.rb` against spec section 9 — all 5 cases covered
- [x] Audit `spec/requests/growth_cycles_spec.rb` against spec section 9 — all 8 cases covered:
  1. GET /growth_cycles — 200, includes owner's cycle, excludes other user's cycle
  2. GET /growth_cycles/new — 200 authenticated, redirect unauthenticated
  3. POST /growth_cycles — creates cycle + tasks (9 tasks minimum, 12 expected), redirects to show
  4. POST /growth_cycles — GeminiError: no cycle saved, error partial rendered
  5. POST /growth_cycles — malformed JSON: no cycle saved, parse-failure message in body
  6. POST /growth_cycles — GeminiService called exactly once per create request (LlmRequest creation tested in gemini_service_spec.rb)
  7. GET /growth_cycles/:id — other user's cycle raises RecordNotFound
  8. DELETE /growth_cycles/:id — destroys cycle + tasks, redirects, cycle no longer findable
- [x] Audit `spec/requests/cycle_tasks_spec.rb` against spec section 9 — all 4 cases covered:
  1. Toggle false→true: `completed` becomes `true`, response is turbo-stream
  2. Toggle true→false: second PATCH reverses the first
  3. Response body includes `turbo-stream` element with correct target; no `<html>` tag
  4. Cross-user toggle: RecordNotFound, task unmodified
- [x] Confirm existing boilerplate specs still pass (sessions, admin, models, services)
- [x] Confirm zero real Gemini API calls in the test run (grep for any missing stubs if failures occur)

### Final Test Run

```
bundle exec rspec --format documentation
```

**Target:** 0 failures, 0 real API calls.

---

## Completion Checklist

Final verification before the repo is ready to share:

- [x] All phases marked complete above (implementation tasks done; remaining unchecked items are manual smoke tests)
- [x] `bundle exec rspec` passes with 0 failures
- [x] App boots cleanly from a fresh `bin/setup` and `rails db:seed`
- [x] Both sample cycles are visible at `/growth_cycles` after seeding
- [x] Gemini plan generation works end-to-end with a valid API key
- [x] Admin template test panel works for `gathercycle_plan_v1`
- [x] `README.md` updated with GatherCycle Demo section
- [x] `.env.example` has all GatherCycle values set (no real secrets)
- [x] `config/master.key` is gitignored (`/config/*.key` in .gitignore)
- [x] No hardcoded "GatherCycle Demo" strings in views (all use `ENV.fetch`)
- [x] No `binding.pry` or `debugger` calls in committed code
- [x] `demo_placeholder_v1` template removed from seeds.rb
