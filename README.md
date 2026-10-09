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

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `gathercycle_plan_v1` must return valid JSON with `phases`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 7 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Useful:** Taken together, the tasks plausibly reach the stated growth goal within the time period, and each success indicator is measurable.
- **Useful:** The workload is distributed sensibly. Tasks are spread across leader, volunteer, and staff owners to match each role's definition, and no single owner type carries an unrealistic load for a small organization.
- **Accurate:** The plan is specific to the organization and audience described, with no invented facts such as budgets, partners, or member counts the input does not mention.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (12/12 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## Built On

This app is built on [Open Demo Starter](https://github.com/natron19/open-base), a minimal Rails 8 + Gemini boilerplate for single-purpose demo apps. The auth system, admin panel, AI service layer, and guardrails are from the boilerplate and are not modified here.

## License

MIT — see [LICENSE](LICENSE)
