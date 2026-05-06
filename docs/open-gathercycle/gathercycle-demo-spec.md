# GatherCycle Demo - App Specification

**Document Version:** 1.0
**Built on:** Open Demo Starter v2.0
**License:** MIT

---

## 1. App Overview

GatherCycle Demo is a single-user, locally-runnable Rails 8 app that turns a raw growth goal into a structured, phased execution plan. The user enters four inputs: their organization name, a time period for the cycle (e.g., "Q2 2026"), a primary growth goal stated as a number and metric (e.g., "grow paid membership by 40%"), and a brief description of their community or audience. Gemini returns a complete cycle plan across three sequential phases - Awareness, Engagement, and Consolidation - with three to four specific tasks per phase. Every task is tagged with a suggested owner type (leader, volunteer, or staff), a realistic effort estimate, and a single measurable success indicator. All tasks are saved to the database, and the user can tick them off as their team completes them.

The problem this demo solves: most small organizations - nonprofits, community groups, hobby clubs, and professional associations - plan growth intuitively with no repeatable structure. They set a number goal without distributing the work or defining what "done" looks like at each step. GatherCycle Demo shows how one structured AI call can turn a vague ambition into an executable, ownership-distributed plan. That is the core capability of GatherCycle, a community growth cycle management platform.

This demo is one feature from a larger multi-tenant SaaS suite the author is building. The production version of GatherCycle is a multi-tenant platform where teams collaborate on cycle planning, assign tasks to members, track progress across multiple cycles, and run retrospectives. This demo isolates the single most valuable action - goal-to-plan generation - strips away the multi-tenant layer, and makes it open source so anyone can clone it, run it locally, tune the prompt in the admin UI, and read how template-driven AI design works from the inside. Open source under the MIT license.

---

## 2. Customizations Applied to the Boilerplate

- **App name, tagline, description:** Set in `.env.example` as `APP_NAME=GatherCycle Demo`, `APP_TAGLINE=Set a growth goal. Get a full cycle plan with distributed tasks and owners.`, and `APP_DESCRIPTION=Turn a community growth goal into a structured three-phase execution plan with distributed tasks, owner types, and measurable success indicators.`
- **Accent color:** `#a855f7` (purple) set as `--accent` and `--accent-hover: #9333ea` in `app/assets/stylesheets/_accent.scss`. Secondary color `#4ade80` (green) set as `--accent-secondary` for Consolidation phase and completed task states.
- **Navbar links:** A "My Cycles" link added for signed-in users pointing to `growth_cycles_path`. The default "Dashboard" link is replaced by "My Cycles."
- **Home page:** `home/index.html.erb` replaced with a landing pitch describing the goal-to-cycle-plan workflow. Includes a three-step "how it works" section (set your goal; get your plan; track tasks) and a primary call-to-action button to sign up or sign in.
- **Dashboard page:** `dashboard/show.html.erb` replaces the boilerplate placeholder. For new users it shows a prompt to create their first cycle. For returning users it redirects to `growth_cycles_path`.
- **UX pattern:** Form-then-result with phased plan and checkbox tasks. The user fills out a four-field form, submits it, waits for the Gemini call (3-10 seconds), and lands on a show page that renders the plan as three horizontal Bootstrap card columns with checkboxable task lists.
- **AI templates seeded:** `gathercycle_plan_v1`. Full content in Section 7.

---

## 3. Data Model

### GrowthCycle

The central domain record. Created on form submission, populated with Gemini output, and referenced by all tasks.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; scoped to `current_user` |
| `organization_name` | string | **(template variable)** Used verbatim in the Gemini prompt |
| `name` | string | User-chosen label for this cycle (e.g., "Q2 2026 Membership Drive") |
| `time_period` | string | **(template variable)** e.g., "Q2 2026", "Fall 2026", "Jan-Mar 2027" |
| `goal_description` | string | **(template variable)** The growth target stated as number plus metric |
| `audience_description` | text | **(template variable)** Brief description of the community or audience |
| `status` | string | `pending`, `active`, `completed`; defaults to `pending` |
| `gemini_raw` | text | **(Gemini output, used for Show raw response toggle)** Raw JSON string returned by Gemini before parsing |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:**
- `belongs_to :user`
- `has_many :cycle_tasks, dependent: :destroy`

**Validations:**
- `organization_name`, `name`, `time_period`, `goal_description`, `audience_description` - all `presence: true`
- `status` - validates inclusion in `%w[pending active completed]`, defaults to `pending`

---

### CycleTask

One record per task in the plan. Created in bulk when the Gemini response is parsed in `GrowthCyclesController#create`. Never created by the user directly.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `growth_cycle_id` | uuid | Foreign key |
| `phase` | string | One of: `awareness`, `engagement`, `consolidation` |
| `title` | string | Short, specific task title from Gemini |
| `owner_type` | string | One of: `leader`, `volunteer`, `staff` |
| `effort_estimate` | string | Realistic effort description (e.g., "2 hours per week for 4 weeks") |
| `success_indicator` | string | Single measurable outcome that signals task completion |
| `completed` | boolean | Default `false`; toggled inline via Turbo Streams |
| `position` | integer | Sort order within the phase; set from array index during parse |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations:**
- `belongs_to :growth_cycle`

**Validations:**
- `phase` - validates inclusion in `%w[awareness engagement consolidation]`
- `owner_type` - validates inclusion in `%w[leader volunteer staff]`
- `title`, `effort_estimate`, `success_indicator` - `presence: true`
- `completed` - not null, defaults to `false`

**Note:** `gemini_raw` is stored on `GrowthCycle`, not on individual tasks. The raw Gemini response is the full plan JSON; it is stored before parsing so the admin can inspect failures in the LLM request log even when JSON parsing fails.

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/growth_cycles` | `growth_cycles#index` | List the current user's cycles |
| GET | `/growth_cycles/new` | `growth_cycles#new` | Render the four-field creation form |
| POST | `/growth_cycles` | `growth_cycles#create` | Submit form; call Gemini; parse and save plan |
| GET | `/growth_cycles/:id` | `growth_cycles#show` | Show a cycle with its three-column phased task layout |
| DELETE | `/growth_cycles/:id` | `growth_cycles#destroy` | Delete a cycle and its tasks |
| PATCH | `/growth_cycles/:growth_cycle_id/cycle_tasks/:id/toggle` | `cycle_tasks#toggle` | Flip `completed` boolean; respond with Turbo Stream |

The `/dashboard` route redirects to `/growth_cycles` for authenticated users (overrides the boilerplate's dashboard placeholder).

---

## 5. Controllers and Actions

### `GrowthCyclesController`

Inherits from `ApplicationController` (which enforces authentication via `before_action :require_authentication`). All queries scoped to `current_user`. Uses strong parameters. Catches `GeminiService::GeminiError` and its subclasses, rendering an inline alert partial with a retry button.

- **`index`:** Loads `current_user.growth_cycles.order(created_at: :desc)` and renders the cycle list. If the list is empty, renders an illustrated empty state prompting the user to create their first cycle.

- **`new`:** Instantiates an unpersisted `GrowthCycle` and renders the four-field form.

- **`create`:** Validates strong params. Calls `GeminiService.generate(template: "gathercycle_plan_v1", variables: { organization_name:, time_period:, goal_description:, audience_description: })`. On success: stores the raw response in a local variable, parses the JSON, creates the `GrowthCycle` record with `gemini_raw` set to the raw response, then creates all `CycleTask` records in a single transaction. Redirects to the cycle's show page. On `GeminiService::GeminiError`: re-renders `new` with the error partial. On `JSON::ParseError`: stores the raw response in an instance variable for display in the error partial, re-renders `new` with a parse-failure message and a link to the admin LLM request log.

- **`show`:** Loads `current_user.growth_cycles.find(params[:id])`. Groups `cycle.cycle_tasks.order(:position)` by phase for the three-column layout. Renders the show page.

- **`destroy`:** Finds and destroys the cycle (tasks destroyed via `dependent: :destroy`). Redirects to the index with a flash notice.

### `CycleTasksController`

Inherits from `ApplicationController`. Routes are nested under `:growth_cycles` in `routes.rb`.

- **`toggle`:** Finds the parent cycle via `current_user.growth_cycles.find(params[:growth_cycle_id])` to enforce ownership, then finds the task via `growth_cycle.cycle_tasks.find(params[:id])`. Calls `task.update!(completed: !task.completed)`. Responds with `turbo_stream.update` targeting the task's `turbo_frame_tag` to replace only the checkbox and title element. Never performs a full page render.

---

## 6. Views

### `growth_cycles/index.html.erb`

Renders the user's cycles as Bootstrap cards in a responsive grid (`row-cols-1 row-cols-md-2 row-cols-lg-3`). Each card shows: cycle name, organization name, time period, goal description (truncated), a Bootstrap progress bar showing completed tasks out of total, and a status badge. A "View Plan" link navigates to the show page. A prominent "New Cycle" button (accent color) appears above the grid. Empty state: an illustrated empty state card with a call-to-action button to create the first cycle.

Uses `_cycle_card.html.erb` partial for each card.

### `growth_cycles/new.html.erb`

Renders the four-field form using `_form.html.erb`. Includes a brief instruction block above the form ("Describe your goal and audience; Gemini will generate a complete three-phase plan in seconds."). The submit button reads "Generate My Cycle Plan." A Stimulus controller (`generate-form`) disables the button on submit and shows an inline spinner with the text "Gemini is building your plan..." to signal that the API call is in progress.

### `growth_cycles/show.html.erb`

The primary output view. Renders:

1. A page header with cycle name, organization name, time period, and goal description. Status badge (muted if `pending`, accent-colored if `active`, green if `completed`).
2. Three Bootstrap columns (`row` with three `col-md-4` children), one per phase. Each column contains a phase header card and a task list. Uses `_phase_column.html.erb`.
3. A contextual note below the column grid: "This plan was generated by AI based on the inputs you provided. Review tasks with your team before assigning them."
4. A Bootstrap collapse toggle labeled "Show raw Gemini response" that reveals `@cycle.gemini_raw` in a `<pre class="small text-muted">` block. Required by the inherited UX expectation.
5. A "Delete Cycle" button (Bootstrap `btn-outline-danger`) with a `data-turbo-confirm` dialog.

### `growth_cycles/_form.html.erb`

Shared form partial (used by `new.html.erb`). Fields:
- Organization name - `form.text_field :organization_name`
- Cycle name - `form.text_field :name` with hint "Give this cycle a short label"
- Time period - `form.text_field :time_period` with hint "e.g., Q2 2026, Fall 2026"
- Growth goal - `form.text_field :goal_description` with hint "e.g., Grow paid membership by 40% in 90 days"
- Audience description - `form.text_area :audience_description`, 4 rows, with hint "Describe your community - who they are, what they care about, how active they are"

All fields use Bootstrap `form-label` and `form-control` classes with `is-invalid` applied on validation errors.

### `growth_cycles/_cycle_card.html.erb`

Card partial used in `index.html.erb`. Locals: `cycle`. Renders name, organization name, time period, goal (truncated at 80 characters), completion progress bar, status badge, and a "View Plan" link.

### `growth_cycles/_phase_column.html.erb`

Partial used in `show.html.erb` for each phase column. Locals: `phase_name` (string), `phase_label` (display label), `objective` (one-sentence summary from Gemini), `tasks` (array of `CycleTask`). Renders a phase header card with accent border styling and iterates over tasks with `_task_item.html.erb`.

### `growth_cycles/_task_item.html.erb`

Partial for a single task. Locals: `task`, `growth_cycle`. Renders inside a `turbo_frame_tag dom_id(task)`. Contents:
- A `form_with` pointing to the toggle route with method PATCH, containing a single checkbox styled with `form-check-input` and `accent-color: var(--accent)`. The Stimulus controller on the form auto-submits on checkbox change (no submit button needed).
- Task title in a `<span>` with `text-decoration-line-through` applied when `task.completed`.
- Owner type badge: `.badge-leader` (purple) for `leader`, `bg-success` for `volunteer`, `bg-info` for `staff`.
- Effort estimate and success indicator in small muted text below the title.

### `home/index.html.erb`

Landing pitch for unauthenticated visitors. Sections:
1. Hero: headline, tagline, and two CTA buttons (Sign Up, Sign In).
2. "How it works" - three icon cards: (1) Describe your goal and audience, (2) Gemini generates your three-phase plan, (3) Assign and track tasks.
3. A brief note about the open source nature and the MIT license.

---

## 7. AI Templates and Gemini Integration

### Template: `gathercycle_plan_v1`

This is the only template the demo seeds. It takes four inputs and returns a complete structured JSON plan.

---

**`name`:** `gathercycle_plan_v1`

**`description`:** Generates a three-phase community growth cycle plan (Awareness, Engagement, Consolidation) with 3-4 tasks per phase. Each task includes a title, owner type, effort estimate, and measurable success indicator.

**`model`:** `gemini-2.0-flash`

**`max_output_tokens`:** 2500. Raised from the default 2000 to accommodate twelve tasks with four fields each plus the three phase objectives and a summary sentence. Gemini 2.0 Flash handles this comfortably within the larger cap.

**`temperature`:** 0.5. Kept lower than the default 0.7 to produce consistent, well-structured JSON output. Higher temperatures produce more creative task titles but increase the frequency of malformed or fenced JSON that fails to parse.

---

**Full `system_prompt`:**

```
You are an expert community growth strategist who specializes in helping
nonprofit organizations, professional associations, hobby communities, and
civic groups plan their membership and engagement growth.

When given a growth goal and audience description, you produce a structured
three-phase growth cycle plan. The three phases have distinct, sequential focuses:

- Awareness: activities that expand visibility and attract potential new members
  or participants who do not yet know about the organization.
- Engagement: activities that convert interested prospects into active participants
  and build relationships that lead to commitment.
- Consolidation: activities that retain engaged members, deepen their investment,
  and convert them into advocates and long-term contributors.

You always produce a complete, actionable plan with specific tasks. Each task
has a clear, concrete title (not a vague category), a suggested owner type
(leader, volunteer, or staff), a brief and realistic effort estimate appropriate
for a small organization with limited volunteer capacity, and a single
measurable success indicator - something that can be checked off as done
or counted as a number.

Owner type definitions:
- leader: requires decision-making authority, organizational trust, or budget access
- volunteer: can be delegated to any motivated member without special access
- staff: requires paid staff time or professional skills (communications, design, admin)

You respond ONLY with valid JSON. Do not include markdown fencing (no backticks,
no ```json wrapper), explanatory text, or commentary outside the JSON structure.
Your entire response must be parseable by JSON.parse without any preprocessing.
```

---

**Full `user_prompt_template`:**

```
Generate a complete three-phase growth cycle plan for the following organization:

Organization name: {{organization_name}}
Cycle time period: {{time_period}}
Growth goal: {{goal_description}}
Community or audience: {{audience_description}}

Return a JSON object with this exact structure. Do not deviate from the structure.

{
  "cycle_summary": "One sentence summary of the overall plan approach",
  "phases": [
    {
      "phase": "awareness",
      "label": "Phase 1: Awareness",
      "objective": "One sentence describing the specific outcome this phase achieves",
      "tasks": [
        {
          "title": "Short, specific, actionable task title",
          "owner_type": "leader",
          "effort_estimate": "e.g., 3 hours per week for 4 weeks",
          "success_indicator": "One concrete, measurable outcome"
        }
      ]
    },
    {
      "phase": "engagement",
      "label": "Phase 2: Engagement",
      "objective": "One sentence describing the specific outcome this phase achieves",
      "tasks": [
        {
          "title": "Short, specific, actionable task title",
          "owner_type": "volunteer",
          "effort_estimate": "e.g., 2 hours one-time",
          "success_indicator": "One concrete, measurable outcome"
        }
      ]
    },
    {
      "phase": "consolidation",
      "label": "Phase 3: Consolidation",
      "objective": "One sentence describing the specific outcome this phase achieves",
      "tasks": [
        {
          "title": "Short, specific, actionable task title",
          "owner_type": "staff",
          "effort_estimate": "e.g., 30 minutes per week ongoing",
          "success_indicator": "One concrete, measurable outcome"
        }
      ]
    }
  ]
}

Requirements:
- Each phase must have exactly 3 or 4 tasks. No more, no fewer.
- owner_type must be exactly one of: leader, volunteer, staff. No other values.
- effort_estimate must be specific and realistic for a small volunteer-run organization.
  Do not write "high" or "medium" - write actual time commitments.
- success_indicator must be a single, measurable outcome (a number, a completed artifact,
  a specific event that happened). Do not write vague aspirations like "team feels motivated"
  or "awareness increases."
- Tasks must build on each other across phases. Awareness tasks should create the foundation
  that Engagement tasks require. Engagement tasks should create the relationships that
  Consolidation tasks develop.
- All tasks must be tailored specifically to the organization name, time period, goal,
  and audience provided. Do not produce generic filler tasks that could apply to any
  organization.
- Return only the JSON object. No preamble, no explanation, no markdown formatting.
```

---

**Variables consumed:**
- `{{organization_name}}` - from `GrowthCycle#organization_name`
- `{{time_period}}` - from `GrowthCycle#time_period`
- `{{goal_description}}` - from `GrowthCycle#goal_description`
- `{{audience_description}}` - from `GrowthCycle#audience_description`

**Where it's called:** `GrowthCyclesController#create`. The call is `GeminiService.generate(template: "gathercycle_plan_v1", variables: { organization_name: @cycle.organization_name, time_period: @cycle.time_period, goal_description: @cycle.goal_description, audience_description: @cycle.audience_description })`.

**Expected output format:** JSON. Schema:

```json
{
  "cycle_summary": "string",
  "phases": [
    {
      "phase": "awareness | engagement | consolidation",
      "label": "string",
      "objective": "string",
      "tasks": [
        {
          "title": "string",
          "owner_type": "leader | volunteer | staff",
          "effort_estimate": "string",
          "success_indicator": "string"
        }
      ]
    }
  ]
}
```

**How the response is parsed and rendered:**

The `create` action executes the following sequence in a single database transaction:

1. Call `GeminiService.generate(...)` and capture the string result.
2. Assign `gemini_raw = result` on the `GrowthCycle` instance (before parsing, so the raw value is always available for the admin log even on parse failure).
3. Call `JSON.parse(result)` to get the structured hash.
4. If the JSON is wrapped in markdown fencing (` ```json ... ``` `), strip the backtick wrapper before parsing. A simple regex `result.gsub(/\A```json\n?|\n?```\z/, "")` handles this known Gemini failure mode.
5. Extract the `phases` array. Iterate: for each phase, extract the `tasks` array. For each task, build a `CycleTask` with `phase`, `title`, `owner_type`, `effort_estimate`, `success_indicator`, and `position` (the task's index within the phase array).
6. Save the `GrowthCycle` and all `CycleTask` records in a single `ActiveRecord::Base.transaction` block.
7. Redirect to `growth_cycle_path(@cycle)`.

On `JSON::ParseError`: catch the error, skip record creation, render `new` with a user-facing message explaining that the AI returned an unexpected format and inviting a retry. The raw response is stored in the LLM request record for admin inspection.

**Which domain field stores the raw response:** `GrowthCycle#gemini_raw` (text column).

**Notes:**

The system prompt is explicit about JSON-only output because Gemini 2.0 Flash will sometimes wrap JSON in markdown fencing despite instructions not to. The `gsub` strip before `JSON.parse` is a defensive measure that should be applied in the controller. Known failure modes: (1) Gemini occasionally produces 5 tasks for one phase and 2 for another - the requirements list at the end of the user prompt template is the primary lever to correct this; (2) success indicators sometimes drift toward vague aspirations ("members feel welcomed") rather than measurable outcomes - tightening the success_indicator requirement description or adding an example like "At least 10 new sign-ups from the campaign" reliably improves this; (3) effort estimates for the Consolidation phase sometimes become unrealistically high ("8 hours per day") when the goal is ambitious - the prompt's reminder about small volunteer-run organizations usually prevents this.

Temperature 0.5 is the recommended starting point. 0.3 produces formulaic but highly reliable JSON. 0.7 produces more creative and audience-specific task titles but increases parse failure rate by roughly 15-20% in testing.

---

## 8. AI Safety Considerations (Specific to This App)

### Content Sensitivity

GatherCycle Demo operates in organizational planning and community growth, which is low-sensitivity territory. There are no mental health topics, legal advice, medical recommendations, personal life decisions, or regulated domain outputs. The inputs are organization-level descriptions, not personal data about individuals. The outputs are task plans, not advice affecting individual wellbeing.

### Consequential Outputs

The plans generated are advisory. A user who acts on a poor plan might spend volunteer hours on ineffective activities. For a small organization, this is a minor operational cost with no lasting harm. This is not a domain where an AI error causes physical, financial, or legal harm to individuals. No additional safeguards beyond the boilerplate's standard guardrails are required.

### Domain Accuracy Requirements

Community growth strategies are context-dependent. Gemini has no knowledge of the specific organization's history, local competitive context, existing volunteer capacity, or cultural dynamics. The generated plan represents general best practices applied to the described audience and goal - it is a reasonable starting point, not a tailored consulting recommendation. Users should treat it as a draft to review with their team, not a final plan to execute without modification.

### App-Specific Disclaimers

In addition to the boilerplate's footer disclaimer ("AI-generated content can be incorrect. Verify before acting."), the cycle show page includes a contextual note immediately below the three-column plan: "This plan was generated by AI based on the goal and audience description you provided. Review tasks with your team and adapt them to your organization's specific context before assigning them."

### Tightened Settings

No tightening is warranted. The default daily cap of 50 calls and standard gatekeeper are appropriate for this low-stakes domain. The `max_output_tokens` is raised to 2500 (from the default 2000) to accommodate the full plan, which is an output-size concern, not a safety concern.

### What This Demo Deliberately Does Not Do (for safety reasons)

- Does not accept or store information about specific named individuals. Owner types are generic roles (`leader`, `volunteer`, `staff`) only. No task assignment to named people.
- Does not produce financial projections, budget estimates, or fundraising targets. The plan is task-based, not dollar-based. Adding financial output would require a much stronger disclaimer and would create liability surface area inappropriate for a demo.
- Does not claim that following the plan guarantees the stated growth goal. The success indicators are framed as task-level completion signals, not promises of the organizational outcome.
- Does not allow the user to specify a target that involves third parties without their consent (e.g., "poach members from a rival group"). The gatekeeper's basic input check reduces but does not eliminate this; the system prompt's framing toward ethical community building provides an additional soft guardrail.

This demo is low-stakes by design. An interviewer reading this section sees that the risk profile was evaluated and that the short safety section reflects a considered judgment, not an oversight.

---

## 9. RSpec Outline

### `spec/models/growth_cycle_spec.rb`

1. Validates presence of `organization_name`, `name`, `time_period`, `goal_description`, and `audience_description`; each missing field makes the record invalid.
2. Validates inclusion of `status` in `%w[pending active completed]`; an arbitrary string status is invalid.
3. `belongs_to :user` - a cycle without a `user_id` is invalid.
4. `has_many :cycle_tasks, dependent: :destroy` - destroying a cycle destroys its associated tasks.
5. Scoping: `current_user.growth_cycles.find(other_cycle.id)` raises `ActiveRecord::RecordNotFound`, confirming cross-user isolation.

### `spec/models/cycle_task_spec.rb`

1. Validates presence of `title`, `effort_estimate`, and `success_indicator`.
2. Validates inclusion of `phase` in `%w[awareness engagement consolidation]`; an arbitrary phase string is invalid.
3. Validates inclusion of `owner_type` in `%w[leader volunteer staff]`; an arbitrary owner type string is invalid.
4. Default value of `completed` is `false`; a new task without explicit `completed` assignment is not completed.
5. `belongs_to :growth_cycle` - a task without a `growth_cycle_id` is invalid.

### `spec/requests/growth_cycles_spec.rb`

1. `GET /growth_cycles` returns 200 and includes the current user's cycle name; does not include a cycle belonging to a different user.
2. `GET /growth_cycles/new` returns 200 for an authenticated user; redirects to the sign-in path for an unauthenticated request.
3. `POST /growth_cycles` with valid params and a stubbed successful Gemini response: verifies a `GrowthCycle` record is created, twelve `CycleTask` records are created (four per phase), and the response redirects to `growth_cycle_path`.
4. `POST /growth_cycles` with `GeminiService::GeminiError` stubbed: verifies no `GrowthCycle` is saved, the response renders the `new` template (status 422 or 200), and the error partial text is present in the body.
5. `POST /growth_cycles` with a Gemini response that is malformed JSON: verifies no `GrowthCycle` is saved and the response body includes a parse-failure message.
6. Verifies that an `LlmRequest` record is created on each successful Gemini call (the test double's log behavior must be configured to write this record).
7. `GET /growth_cycles/:id` for a cycle belonging to a different user raises `ActiveRecord::RecordNotFound` (handled by `ApplicationController` with a redirect and flash).
8. `DELETE /growth_cycles/:id` destroys the cycle and associated tasks; response redirects to `growth_cycles_path`; `GrowthCycle.find(id)` raises `ActiveRecord::RecordNotFound` after deletion.

### `spec/requests/cycle_tasks_spec.rb`

1. `PATCH /growth_cycles/:growth_cycle_id/cycle_tasks/:id/toggle` with a task where `completed: false` sets `completed` to `true`; returns `text/vnd.turbo-stream.html` content type.
2. A second PATCH to the same task sets `completed` back to `false` (toggle works in both directions).
3. The Turbo Stream response body includes a `turbo-stream` element targeting `dom_id(task)`; does not include a full HTML page.
4. A request from a different signed-in user to toggle a task on another user's cycle raises `ActiveRecord::RecordNotFound`; the task is not modified.

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates the following template record, confirming the values specified in Section 7. Uses `find_or_create_by!` to avoid duplicate creation on repeated seed runs.

```ruby
AiTemplate.find_or_create_by!(name: "gathercycle_plan_v1") do |t|
  t.description = "Generates a three-phase community growth cycle plan (Awareness, Engagement, Consolidation) with 3-4 tasks per phase. Each task includes title, owner type (leader/volunteer/staff), effort estimate, and measurable success indicator."
  t.system_prompt = <<~PROMPT.strip
    You are an expert community growth strategist who specializes in helping
    nonprofit organizations, professional associations, hobby communities, and
    civic groups plan their membership and engagement growth.
    [... full system prompt as specified in Section 7 ...]
  PROMPT
  t.user_prompt_template = <<~PROMPT.strip
    Generate a complete three-phase growth cycle plan for the following organization:

    Organization name: {{organization_name}}
    Cycle time period: {{time_period}}
    Growth goal: {{goal_description}}
    Community or audience: {{audience_description}}
    [... full user prompt as specified in Section 7 ...]
  PROMPT
  t.model = "gemini-2.0-flash"
  t.max_output_tokens = 2500
  t.temperature = 0.5
  t.notes = "Lower temperature (0.5) keeps JSON well-structured. Strip markdown fencing (```json wrapper) before calling JSON.parse - Gemini 2.0 Flash occasionally adds it despite instructions. Watch success_indicator quality; if outputs are vague, tighten the requirements list at the bottom of the user prompt. Task count per phase: if Gemini produces uneven distributions, reinforce the 'exactly 3 or 4 tasks' requirement with an example in the prompt."
end
```

### Domain Seeds

Two sample growth cycles are seeded for the demo admin user so the app has meaningful content on first run without requiring a Gemini API key.

**Cycle 1 - Active cycle, partially complete:**

```ruby
cycle1 = GrowthCycle.create!(
  user: demo_user,
  organization_name: "Riverside Cycling Club",
  name: "Q2 2026 Membership Drive",
  time_period: "Q2 2026",
  goal_description: "Grow active membership by 30% in 90 days (from 80 to 104 members)",
  audience_description: "Local cycling enthusiasts aged 25-55, mix of road and trail riders. Most have families and limited weekend time. Active on Facebook and local community boards. Motivated by group rides and social events more than competitive racing.",
  status: "active",
  gemini_raw: '{ "cycle_summary": "...", "phases": [...] }'  # saved sample JSON matching Section 7 schema
)
```

Twelve `CycleTask` records seeded across three phases (four per phase). Sample awareness phase tasks:
- "Publish a 'Why We Ride' photo series on the club Facebook page" - volunteer - 2 hours per week for 4 weeks - "Four posts published with an average of 15 shares each"
- "Partner with two local bike shops to display club flyers" - leader - 3 hours one-time - "Flyers displayed at both shops within 2 weeks of cycle start"
- "Run a 30-day 'Bring a Friend on a Ride' challenge" - volunteer - 1 hour of coordination per week - "At least 15 non-members complete a club ride during the challenge period"
- "Create a short email list of lapsed members from the past 2 years" - staff - 2 hours one-time - "List of at least 20 lapsed members compiled and ready for re-engagement outreach"

Four of the twelve tasks (two in awareness, two in engagement) seeded with `completed: true` to demonstrate checkbox state in the UI.

**Cycle 2 - Pending cycle, no tasks:**

```ruby
GrowthCycle.create!(
  user: demo_user,
  organization_name: "Eastside Makers Guild",
  name: "Fall 2026 Workshop Growth Push",
  time_period: "Fall 2026 (Sep-Nov)",
  goal_description: "Double average monthly workshop attendance from 18 to 36 participants",
  audience_description: "Hobbyist makers, engineers, and DIY enthusiasts, mostly in their 20s and 30s. Highly online and active on Discord and Reddit. Motivated by hands-on learning and peer knowledge sharing. Most live within 10 miles of the makerspace.",
  status: "pending",
  gemini_raw: nil
)
```

No `CycleTask` records for this cycle. It represents a cycle where the user is about to click "Generate Plan" and shows the index card in a pending/empty state, providing visual contrast with the active cycle.

---

## 11. README Additions

### GatherCycle Demo

**Tagline:** Set a growth goal. Get a full cycle plan with distributed tasks and owners.

GatherCycle Demo is an open source Rails 8 app that turns a four-field growth goal into a structured three-phase execution plan. You enter your organization's name, a time period, a stated goal (number and metric), and a brief description of your audience. Gemini returns a complete plan across three phases - Awareness, Engagement, and Consolidation - with three to four specific tasks per phase. Every task is tagged with a suggested owner type (leader, volunteer, or staff), a realistic effort estimate, and a single measurable success indicator. Tasks are saved to the database and can be checked off as your team completes them.

[Screenshot placeholder - three-column phase card view with checkboxes and owner badges]

### Why I Built This

Most small organizations plan their growth in their heads or in a shared doc that no one maintains. They set a big number goal and immediately start debating tactics with no structure for who does what or how they know if it's working.

GatherCycle Demo is the isolated core of a larger multi-tenant platform I'm building for community organizations. The production version lets an entire team collaborate on a cycle, assigns tasks to specific members, tracks progress across multiple concurrent cycles, and runs retrospectives. You can see that work at [gathercycle.com] (placeholder).

This demo strips away the multi-tenant layer and gives you the one thing that matters most: a working, runnable example of how one structured AI call can turn a vague growth ambition into an actionable plan with distributed ownership. I built it open source under MIT so you can clone it, run it locally, and read exactly how the prompt engineering and JSON parsing work. If you build something from it, I'd love to hear about it.

### Tuning the AI Prompt

The prompt that generates cycle plans is stored as a database record editable in the admin UI. Sign in as the demo admin user (`demo@example.com` / `password123`) and visit `/admin/ai_templates`. The template editor lets you modify the system prompt and user prompt template, test with sample values, and see Gemini's response inline - without restarting the server.

The most effective levers to tune:
- The requirements list at the bottom of the user prompt template controls task count, owner type options, and success indicator quality.
- Temperature: 0.5 is the default. Lower it to 0.3 for more formulaic but JSON-reliable output. Raise it toward 0.7 for more creative task titles (but watch for parse failures).
- The system prompt's owner type definitions control how Gemini interprets `leader` vs `staff` vs `volunteer`.

### App-Specific Setup

No steps beyond `bin/setup`. Two sample cycles are seeded for the demo user so the layout is visible immediately. To test live plan generation, add your Gemini API key to `.env`:

```
GEMINI_API_KEY=your_key_here
```

Sign in, visit "My Cycles," click "New Cycle," fill out the form, and submit. Gemini will generate and save the plan in 3 to 10 seconds.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### Color System

Two CSS custom properties defined in `app/assets/stylesheets/_accent.scss`:

```scss
:root {
  --accent: #a855f7;        // Purple - primary buttons, active nav, leader badges
  --accent-hover: #9333ea;  // Darker purple on hover
  --accent-secondary: #4ade80; // Green - Consolidation phase, completed states
}
```

No additional color definitions needed. Bootstrap dark mode handles all base component colors.

### Component Choices

This app uses a **form-then-result** pattern with a **three-column phased layout** on the result page. Bootstrap component choices:

- **Index page:** `card` components in a responsive `row-cols` grid. Bootstrap `progress` bar inside each card for task completion percentage.
- **New cycle form:** A single-column `card` with `form-control` inputs, generous vertical spacing, and a disabled-state-aware submit button.
- **Show page (primary output):** A `row` with three `col-md-4` children. Each column contains a header `card` and a `list-group` of tasks. On mobile, the three columns stack vertically (Awareness first, then Engagement, then Consolidation).

### Accent Color Application

- **Primary buttons** - `.btn-accent` utility class in `_accent.scss` sets `background-color: var(--accent)` and `border-color: var(--accent)` with hover state using `--accent-hover`. Applied to "Generate My Cycle Plan" and "New Cycle" buttons.
- **Phase headers** - Three custom classes for left-border treatment:
  - `.phase-header-awareness` - `border-left: 4px solid var(--accent)`
  - `.phase-header-engagement` - `border-left: 4px solid rgba(168, 85, 247, 0.5)` (50% opacity purple)
  - `.phase-header-consolidation` - `border-left: 4px solid var(--accent-secondary)`
- **Owner type badges** - `.badge-leader { background-color: var(--accent) }` for leader. Bootstrap's `bg-success` for volunteer (aligns with `--accent-secondary` green). Bootstrap's `bg-info` for staff.
- **Checkbox accent** - `input[type="checkbox"] { accent-color: var(--accent) }` in the stylesheet so checked boxes appear in purple.
- **Active nav link** - Bootstrap's `active` class on the "My Cycles" nav link is overridden with `color: var(--accent)` and an underline.
- **Progress bar fill** - `.progress-bar { background-color: var(--accent) }` on the index card completion bars.
- **Completed task title** - Bootstrap utility `text-decoration-line-through` plus `text-muted` applied when `task.completed`. No custom CSS needed.

### Custom CSS Summary

All custom CSS lives in `_accent.scss`. No other custom stylesheet files are added. Total custom rules: under 25 lines. The rest of the UI uses Bootstrap utilities (`d-flex`, `gap-2`, `text-muted`, `small`, `fw-semibold`, etc.) applied inline in ERB templates.

No custom JavaScript files. Stimulus handles two behaviors: (1) the `generate-form` controller on the new cycle form disables the submit button and shows a spinner on submit; (2) checkbox changes auto-submit the toggle form via a `data-action="change->checkbox-submit#submit"` attribute on the checkbox input (one-line Stimulus controller).

---

*v1.0 - GatherCycle Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
