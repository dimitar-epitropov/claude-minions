---
name: code
description: >-
  Use when a feature's PLAN.md is settled and the tasks need to become real commits — "code this
  feature", "implement the plan", "execute PLAN.md", "build these tasks", re-running after a
  blocked task, or when /minions:feature reaches the code step. This is the minions code step:
  normally invoked by /minions:feature, but runnable directly to execute (or resume) the active
  feature's PLAN.md without restarting the workflow.
argument-hint: "[--tasks=T3..] [--auto]"
arguments:
  - tasks
---

# minions: code

Announce: **"Running minions code — executing the plan into commits."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode`, `auto`, and `skills.coder`. If `--auto` was passed, set
auto to on. If `--tasks=<range>` was passed, record that range (default: `all`).

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/PLAN.md` does not exist, tell the user to run `/minions:plan` first and stop.

**STATE ownership — this skill's only STATE write:** update STATE.md now, before dispatch: set Step
to `code`, Status to `in progress`, Next to `/minions:code` (self), Updated to today. This ensures
an interrupted run is resumable. Do NOT write a "done" status here — the coder agent writes the
end-of-run STATE update (Step `code` → done, Next: `/minions:verify`) at the end of its run.

## Step 3 — Dispatch the coder

Build the skill-pack instruction from `config.skills.coder`:
- If the list is non-empty: `Before coding, invoke and obey these skills: <comma-separated list>`
- If the list is empty: `Before coding, note: no project skill-packs configured`

Use the Agent tool with `subagent_type: minions:coder`. Pass a self-contained prompt containing
everything the agent needs — it must not hunt:

```
Feature folder: <absolute path to feature folder>
Mode: <maintain|vibe>
PLAN.md: <absolute path to PLAN.md>
Tasks: <all | the --tasks= range, e.g. T3..>

<skill-pack instruction from above>
```

Do NOT implement the tasks yourself. Do NOT write or commit code yourself. That is the coder's job.

## Step 4 — Relay & pause

When the agent returns, relay its full `Result / Summary / Next` block verbatim. Surface the path
to `PLAN.md` so the user can see task progress and any deviations. (The agent has already written
the end-of-run STATE update.)

Unless `auto` is on, **stop here** — tell the user the coding run is complete and suggest
`/minions:verify` as the next step. Wait for them to proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never writes code, never makes commits, and never
dispatches any agent other than `minions:coder`. All domain reasoning — the task execution, the
deviation decisions, the commit sequencing — belongs to the agent. If you find yourself writing
implementation here, stop: put it in the dispatch prompt as context, not as output.
