---
name: plan
description: >-
  Use when a feature's SPEC (and ARCH, if it exists) is settled and needs to be turned into an
  executable task list — "plan this feature", "break the spec into tasks", re-planning the active
  feature, or when /minions:feature reaches the plan step. This is the minions plan step: normally
  invoked by /minions:feature, but runnable directly to (re)write the active feature's PLAN.md
  without restarting the workflow.
argument-hint: "[--auto]"
arguments: []
---

# minions: plan

Announce: **"Running minions plan — turning the spec into an executable task list."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode` and `auto`. If `--auto` was passed, set auto to on.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/SPEC.md` does not exist, tell the user to run `/minions:specify` first and stop.

**STATE ownership — this skill's only STATE write:** update STATE.md now, before dispatch: set Step
to `plan`, Status to `in progress`, Next to `/minions:plan` (self), Updated to today. This ensures
an interrupted run is resumable. Do NOT write a "done" status here — the planner agent writes the
end-of-run STATE update (Step `plan` → done, Next: `/minions:code`) at the end of its run.

## Step 3 — Dispatch the planner

Use the Agent tool with `subagent_type: minions:planner`. Pass a self-contained prompt containing
everything the agent needs — it must not hunt:

```
Feature folder: <absolute path to feature folder>
Mode: <maintain|vibe>
SPEC.md: <absolute path to SPEC.md>
ARCH.md: <absolute path to ARCH.md>

Read these files (and nothing beyond what is listed here):
- <root>/PRODUCT.md
- <root>/TECH.md
- <list the real files/modules the feature will touch — read SPEC.md Goals/ACs to identify them>
```

If `<feature>/ARCH.md` does not exist yet, omit the ARCH.md line entirely (the architect step arrives in increment 3).

Do NOT plan the feature yourself. Do NOT write PLAN.md yourself. That is the planner's job.

**Note — plan-check loop (deferred to increment 3):** The full planner ⇄ verifier (`mode: plan`)
loop, governed by `config.loops.plan_check`, is not wired here yet. For now this step dispatches
the planner once. Increment 3 will add the loop.

## Step 4 — Relay & pause

When the agent returns, relay its full `Result / Summary / Next` block verbatim. Surface the path
to `PLAN.md` so the user can open it. (The agent has already written the end-of-run STATE update.)

Unless `auto` is on, **stop here** — tell the user the plan is ready for review and suggest
`/minions:code` as the next step. Wait for them to proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never writes PLAN.md, never analyses the spec, and
never dispatches any agent other than `minions:planner`. All domain reasoning — the task breakdown,
grounding, the goal-backward check — belongs to the agent. If you find yourself writing plan
content here, stop: put it in the dispatch prompt as context, not as output.
