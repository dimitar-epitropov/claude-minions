---
name: verify
description: >-
  Use when a feature has been built and needs to be checked against its acceptance criteria —
  "verify this feature", "did we meet the spec", "check the ACs", a feature claiming done that
  might be stubbed, or when /minions:feature reaches the verify step. This is the minions verify
  step: normally invoked by /minions:feature, but runnable directly to (re)verify the active
  feature without restarting the workflow.
argument-hint: "[--auto]"
arguments: []
---

# minions: verify

Announce: **"Running minions verify — checking the built feature against its acceptance criteria."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode` and `auto`. If `--auto` was passed, set auto to on.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/SPEC.md` does not exist, tell the user to run `/minions:specify` first and stop.
If `<feature>/PLAN.md` does not exist, tell the user to run `/minions:plan` first and stop.

**STATE ownership — this skill's only STATE write:** update STATE.md now, before dispatch: set Step
to `verify`, Status to `in progress`, Next to `/minions:verify` (self), Updated to today. This
ensures an interrupted run is resumable. Do NOT write a "done" status here — the verifier agent
writes the end-of-run STATE update (Step `verify` → done, Next step) at the end of its run.

## Step 3 — Dispatch the verifier

Use the Agent tool with `subagent_type: minions:verifier`. Pass a self-contained prompt containing
everything the agent needs — it must not hunt:

```
Feature folder: <absolute path to feature folder>
Mode: code
SPEC.md: <absolute path to SPEC.md>
PLAN.md: <absolute path to PLAN.md>

Read these files (real code and tests this feature touched — read PLAN.md tasks to identify them):
- <list the actual source files / test files the feature's tasks wrote or modified>
```

The `mode: code` field is required — it tells the verifier to check the built implementation
against SPEC's ACs (not to check a plan pre-implementation).

Do NOT verify the feature yourself. Do NOT write verdicts yourself. That is the verifier's job.

## Step 4 — Relay & pause

When the agent returns, relay its full `Result / Summary / Next` block verbatim. Surface the path
to `PLAN.md ## Verification` so the user can see per-AC verdicts. (The agent has already written
the end-of-run STATE update.)

Unless `auto` is on, **stop here** — tell the user the verification is complete and suggest
`/minions:review` as the next step (note: not built until increment 3 — fall back to
`/minions:reconcile` or "address FAILED criteria" if review is unavailable). Wait for them to
proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never checks code, never writes verdicts, and never
dispatches any agent other than `minions:verifier`. All domain reasoning — the AC-by-AC check,
the TRUE/EXIST/WIRED analysis, the stub detection — belongs to the agent. If you find yourself
writing verification conclusions here, stop: put it in the dispatch prompt as context, not as
output.
