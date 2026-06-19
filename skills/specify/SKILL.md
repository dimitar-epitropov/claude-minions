---
name: specify
description: >-
  Use when a feature request needs to be clarified and scoped into a testable spec — "specify this
  feature", "write a spec for X", "let's define what we're building", re-specifying an existing
  feature, or when /minions:feature reaches the specify step. This is the minions specify step:
  normally invoked by /minions:feature, but runnable directly to (re)write the active feature's
  SPEC.md without restarting the workflow.
argument-hint: "[request] [--auto] [--questions=none|few|regular|many]"
arguments:
  - request
---

# minions: specify

Announce: **"Running minions specify — clarifying the feature into a spec."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode`, `questions`, and `auto`. Apply per-invocation overrides:
if `--questions=<value>` was passed, use it; if `--auto` was passed, set auto to on.

## Step 2 — Find or create the feature folder

Read STATE.md. If it records an active feature whose `specify` step is not yet done, reuse that
feature folder (this is a resume — do not create a new one).

Otherwise create `<root>/features/NNN-slug/` where:
- `NNN` is the next zero-padded 3-digit integer across existing `features/*` dirs (e.g. 001, 002).
  Count only immediate subdirs of `features/` (not `archive/`).
- `slug` is a short kebab-case slug of the request (3–5 words max).

Use Bash: `mkdir -p <root>/features/<NNN-slug>`.

Update STATE.md: set Workflow to `feature`, Feature to `<NNN-slug>`, Step to `specify`,
Status to `in progress`, Next to `/minions:specify` (self, until agent completes), Updated to today.

## Step 3 — Dispatch the specificator

Use the Agent tool with `subagent_type: minions:specificator`. Pass a self-contained prompt
containing everything the agent needs — it must not hunt:

```
Feature folder: <absolute path to feature folder>
Mode: <maintain|vibe>
Questions budget: <none|few|regular|many>
Request: <the raw $ARGUMENTS / $0 text>

Read these files (and nothing beyond what is listed here):
- <root>/PRODUCT.md
- <root>/TECH.md
- (light codebase context if the request names specific files or modules — list them here)
```

Do NOT conduct the interview yourself. Do NOT write SPEC.md yourself. That is the specificator's job.

## Step 4 — Relay & pause

When the agent returns, relay its full `Result / Summary / Next` block verbatim. Surface the path
to `SPEC.md` so the user can open it.

Unless `auto` is on, **stop here** — tell the user the spec is ready for review and suggest
`/minions:architect` (or `/minions:plan` if architect isn't available yet) as the next step. Wait
for them to proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never asks interview questions, never writes SPEC.md,
and never dispatches any agent other than `minions:specificator`. All domain reasoning — the
interview, the acceptance criteria, the spec prose — belongs to the agent. If you find yourself
writing spec content here, stop: put it in the dispatch prompt as context, not as output.
