# GatherCycle Demo

> Set a growth goal. Get a full cycle plan with distributed tasks and owners.

GatherCycle Demo is an open source Rails 8 app that turns a four-field growth goal into a structured three-phase execution plan. You enter your organization's name, a time period, a stated goal, and a brief description of your audience. Gemini returns a complete plan across three phases — Awareness, Engagement, and Consolidation — with three to four specific tasks per phase. Every task is tagged with a suggested owner type (leader, volunteer, or staff), a realistic effort estimate, and a single measurable success indicator. Tasks are saved to the database and can be checked off as your team completes them.

## Why I Built This

Most small organizations plan their growth in their heads or in a shared doc that no one maintains. They set a big number goal and immediately start debating tactics with no structure for who does what or how they know if it's working.

GatherCycle Demo is the isolated core of a larger platform I'm building for community organizations. This demo strips away the multi-tenant layer and gives you the one thing that matters most: a working, runnable example of how one structured AI call can turn a vague growth ambition into an actionable plan with distributed ownership. Built open source under MIT so you can clone it, run it locally, and read exactly how the prompt engineering and JSON parsing work.

## Quick Start

```bash
git clone <repo>
cd open-gathercycle
bin/setup
```

Add your Gemini API key to `.env`:

```
GEMINI_API_KEY=your_key_here
```

```bash
bin/rails db:seed
bin/rails server
```

Visit `http://localhost:3000` and sign in with `demo@example.com` / `password123`.

Two sample cycles are seeded for the demo user so the layout is visible immediately — no Gemini key required to browse.

## Generating a Plan

Sign in, visit **My Cycles**, click **New Cycle**, fill out the four fields, and submit. Gemini will generate and save the plan in 3–10 seconds. The plan appears as a three-column view (Awareness → Engagement → Consolidation) with checkable tasks.

## Tuning the AI Prompt

The prompt that generates cycle plans is stored as a database record editable in the admin UI. Sign in as the demo admin and visit `/admin/ai_templates`. The template editor lets you modify the system prompt and user prompt template, test with sample values, and see Gemini's response inline — without restarting the server.

The most effective levers:
- **Requirements list** at the bottom of the user prompt template controls task count, owner type options, and success indicator quality.
- **Temperature** — `0.5` is the default. Lower to `0.3` for more formulaic but JSON-reliable output. Raise toward `0.7` for more creative task titles (watch for parse failures).
- **System prompt owner type definitions** control how Gemini interprets `leader` vs `staff` vs `volunteer`.

## Demo Credentials

| Email | Password | Role |
|---|---|---|
| `demo@example.com` | `password123` | Admin |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"GatherCycle Demo"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown in the footer |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required for generation) | Google Gemini API key — get one free at https://aistudio.google.com/app/apikey |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout in seconds |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini 2.5 Flash via Faraday |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## AI Safety Posture

- Per-user daily call cap (default: 50/day, via `AI_CALLS_PER_USER_PER_DAY`)
- Pre-flight gatekeeper: input length limit, prompt injection patterns, profanity filter
- Hard output token cap per template
- Configurable request timeout (default: 15s)
- Full request log with status, tokens, duration, and cost estimate
- Fail-soft UI: errors render an inline alert, never crash the page
- AI disclaimer in the footer on every page

## Built On

This app is built on [Open Demo Starter](https://github.com/your-handle/open-base), a minimal Rails 8 + Gemini boilerplate for single-purpose demo apps. The auth system, admin panel, AI service layer, and guardrails are from the boilerplate and are not modified here.

## License

MIT — see [LICENSE](LICENSE)
