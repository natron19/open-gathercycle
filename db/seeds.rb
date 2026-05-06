# Admin user — credentials for local demo use only
demo_user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.name                  = "Demo User"
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.admin                 = true
end

puts "Demo user: demo@example.com / password123"

# Health ping template — used by /up/llm
AiTemplate.find_or_create_by!(name: "health_ping") do |t|
  t.description          = "Minimal prompt used by the /up/llm health check endpoint."
  t.system_prompt        = "You are a health check endpoint. Respond with exactly: ok"
  t.user_prompt_template = "ping"
  t.model                = "gemini-2.5-flash"
  t.max_output_tokens    = 10
  t.temperature          = 0.0
  t.notes                = "Do not modify. Used by HealthController#llm."
end

puts "Seeded: health_ping AI template"

# GatherCycle plan generation template
AiTemplate.find_or_create_by!(name: "gathercycle_plan_v1") do |t|
  t.description = "Generates a three-phase community growth cycle plan (Awareness, Engagement, Consolidation) with 3-4 tasks per phase. Each task includes a title, owner type, effort estimate, and measurable success indicator."

  t.system_prompt = <<~PROMPT.strip
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
  PROMPT

  t.user_prompt_template = <<~PROMPT.strip
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
  PROMPT

  t.model             = "gemini-2.5-flash"
  t.max_output_tokens = 8192
  t.temperature       = 0.5
  t.notes             = "Called by GrowthCyclesController#create. Returns structured JSON with phases array. Strip markdown fencing before JSON.parse (known Gemini failure mode)."
end

puts "Seeded: gathercycle_plan_v1 AI template"

# ---------------------------------------------------------------------------
# Sample growth cycles — demo content that works without a Gemini API key
# ---------------------------------------------------------------------------

RIVERSIDE_RAW = JSON.generate({
  "cycle_summary" => "Build visibility through social content and local partnerships, convert interested riders through welcome events and buddy pairings, then lock in long-term commitment through recognition and structured communication.",
  "phases" => [
    {
      "phase" => "awareness",
      "label" => "Phase 1: Awareness",
      "objective" => "Expand the club's visibility among local cyclists who don't yet know about Riverside Cycling Club.",
      "tasks" => [
        { "title" => "Publish a 'Why We Ride' photo series on the club Facebook page", "owner_type" => "volunteer", "effort_estimate" => "2 hours per week for 4 weeks", "success_indicator" => "Four posts published with an average of 15 shares each" },
        { "title" => "Partner with two local bike shops to display club flyers", "owner_type" => "leader", "effort_estimate" => "3 hours one-time", "success_indicator" => "Flyers displayed at both shops within 2 weeks of cycle start" },
        { "title" => "Run a 30-day 'Bring a Friend on a Ride' challenge", "owner_type" => "volunteer", "effort_estimate" => "1 hour of coordination per week", "success_indicator" => "At least 15 non-members complete a club ride during the challenge period" },
        { "title" => "Create a short email list of lapsed members from the past 2 years", "owner_type" => "staff", "effort_estimate" => "2 hours one-time", "success_indicator" => "List of at least 20 lapsed members compiled and ready for re-engagement outreach" }
      ]
    },
    {
      "phase" => "engagement",
      "label" => "Phase 2: Engagement",
      "objective" => "Convert interested prospects and returning riders into paid, active members.",
      "tasks" => [
        { "title" => "Host a free 'Try a Club Ride' open day", "owner_type" => "leader", "effort_estimate" => "4 hours one-time", "success_indicator" => "At least 20 non-members attend and receive membership info" },
        { "title" => "Send a re-engagement email to lapsed member list", "owner_type" => "staff", "effort_estimate" => "2 hours one-time", "success_indicator" => "Email sent to full list with at least 30% open rate" },
        { "title" => "Pair each new or returning member with a 'ride buddy'", "owner_type" => "volunteer", "effort_estimate" => "30 minutes per new member", "success_indicator" => "Every new member joined in Q2 has been paired with a buddy within one week of joining" },
        { "title" => "Run a limited-time membership discount for friend referrals", "owner_type" => "leader", "effort_estimate" => "1 hour setup", "success_indicator" => "At least 8 new memberships attributed to the referral offer" }
      ]
    },
    {
      "phase" => "consolidation",
      "label" => "Phase 3: Consolidation",
      "objective" => "Retain new members past the 90-day mark and convert them into active club advocates.",
      "tasks" => [
        { "title" => "Publish end-of-quarter member milestone post", "owner_type" => "volunteer", "effort_estimate" => "1 hour one-time", "success_indicator" => "Post published celebrating new member count with at least 25 reactions" },
        { "title" => "Send a 90-day member satisfaction survey", "owner_type" => "staff", "effort_estimate" => "2 hours one-time", "success_indicator" => "At least 60% of new Q2 members respond to the survey" },
        { "title" => "Invite top-engaged new members to join a ride-leader training session", "owner_type" => "leader", "effort_estimate" => "3 hours one-time", "success_indicator" => "At least 3 new members complete ride-leader orientation" },
        { "title" => "Create a recurring monthly social ride specifically for newer members", "owner_type" => "volunteer", "effort_estimate" => "1 hour planning per month", "success_indicator" => "First social ride held with at least 10 attendees" }
      ]
    }
  ]
})

cycle1 = GrowthCycle.find_or_create_by!(
  user: demo_user,
  name: "Q2 2026 Membership Drive"
) do |c|
  c.organization_name    = "Riverside Cycling Club"
  c.time_period          = "Q2 2026"
  c.goal_description     = "Grow active membership by 30% in 90 days (from 80 to 104 members)"
  c.audience_description = "Local cycling enthusiasts aged 25-55, mix of road and trail riders. Most have families and limited weekend time. Active on Facebook and local community boards. Motivated by group rides and social events more than competitive racing."
  c.status               = "active"
  c.gemini_raw           = RIVERSIDE_RAW
end

awareness_tasks = [
  { title: "Publish a 'Why We Ride' photo series on the club Facebook page", owner_type: "volunteer", effort_estimate: "2 hours per week for 4 weeks", success_indicator: "Four posts published with an average of 15 shares each", completed: true },
  { title: "Partner with two local bike shops to display club flyers", owner_type: "leader", effort_estimate: "3 hours one-time", success_indicator: "Flyers displayed at both shops within 2 weeks of cycle start", completed: true },
  { title: "Run a 30-day 'Bring a Friend on a Ride' challenge", owner_type: "volunteer", effort_estimate: "1 hour of coordination per week", success_indicator: "At least 15 non-members complete a club ride during the challenge period", completed: false },
  { title: "Create a short email list of lapsed members from the past 2 years", owner_type: "staff", effort_estimate: "2 hours one-time", success_indicator: "List of at least 20 lapsed members compiled and ready for re-engagement outreach", completed: false }
]

engagement_tasks = [
  { title: "Host a free 'Try a Club Ride' open day", owner_type: "leader", effort_estimate: "4 hours one-time", success_indicator: "At least 20 non-members attend and receive membership info", completed: true },
  { title: "Send a re-engagement email to lapsed member list", owner_type: "staff", effort_estimate: "2 hours one-time", success_indicator: "Email sent to full list with at least 30% open rate", completed: true },
  { title: "Pair each new or returning member with a 'ride buddy'", owner_type: "volunteer", effort_estimate: "30 minutes per new member", success_indicator: "Every new member joined in Q2 has been paired with a buddy within one week of joining", completed: false },
  { title: "Run a limited-time membership discount for friend referrals", owner_type: "leader", effort_estimate: "1 hour setup", success_indicator: "At least 8 new memberships attributed to the referral offer", completed: false }
]

consolidation_tasks = [
  { title: "Publish end-of-quarter member milestone post", owner_type: "volunteer", effort_estimate: "1 hour one-time", success_indicator: "Post published celebrating new member count with at least 25 reactions", completed: false },
  { title: "Send a 90-day member satisfaction survey", owner_type: "staff", effort_estimate: "2 hours one-time", success_indicator: "At least 60% of new Q2 members respond to the survey", completed: false },
  { title: "Invite top-engaged new members to join a ride-leader training session", owner_type: "leader", effort_estimate: "3 hours one-time", success_indicator: "At least 3 new members complete ride-leader orientation", completed: false },
  { title: "Create a recurring monthly social ride specifically for newer members", owner_type: "volunteer", effort_estimate: "1 hour planning per month", success_indicator: "First social ride held with at least 10 attendees", completed: false }
]

[
  ["awareness",     awareness_tasks],
  ["engagement",    engagement_tasks],
  ["consolidation", consolidation_tasks]
].each do |phase, tasks|
  tasks.each_with_index do |attrs, idx|
    CycleTask.find_or_create_by!(growth_cycle: cycle1, title: attrs[:title]) do |t|
      t.phase             = phase
      t.owner_type        = attrs[:owner_type]
      t.effort_estimate   = attrs[:effort_estimate]
      t.success_indicator = attrs[:success_indicator]
      t.completed         = attrs[:completed]
      t.position          = idx
    end
  end
end

puts "Seeded: Riverside Cycling Club cycle with 12 tasks (4 completed)"

GrowthCycle.find_or_create_by!(
  user: demo_user,
  name: "Fall 2026 Workshop Growth Push"
) do |c|
  c.organization_name    = "Eastside Makers Guild"
  c.time_period          = "Fall 2026 (Sep-Nov)"
  c.goal_description     = "Double average monthly workshop attendance from 18 to 36 participants"
  c.audience_description = "Hobbyist makers, engineers, and DIY enthusiasts, mostly in their 20s and 30s. Highly online and active on Discord and Reddit. Motivated by hands-on learning and peer knowledge sharing. Most live within 10 miles of the makerspace."
  c.status               = "pending"
  c.gemini_raw           = nil
end

puts "Seeded: Eastside Makers Guild cycle (pending, no tasks)"
