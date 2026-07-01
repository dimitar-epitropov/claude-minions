---
name: quick-plan
description: >-
  The minions quick `--plan` step; normally invoked by `/minions:quick --plan`. Plans a small
  change via the planner agent, codes and reviews it via quick-code, then verifies task-backward.
argument-hint: "[request] [--auto]"
---

# minions: quick-plan

Announce: **"Running minions quick --plan — plan, code, review, verify."**

## Step 1 — Resolve config (NOT STATE)

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, stop; otherwise default to `docs/minions/`.

Read `<root>/config.yml` (if missing, tell user to run `/minions:init` and stop). Extract `mode`
and `auto`. If `--auto` was passed, set auto to on. **Stateless:** never read or write STATE.md.

## Step 2 — Ensure scratch directory

Ensure `<root>/quick/` exists (create if absent). Scratch PLAN path: `<root>/quick/PLAN.md`.
<!-- Scratch PLAN is transient — overwritten each run, never archived, not committed by this flow. -->

## Step 3 — Dispatch the planner (quick mode)

Agent tool, `subagent_type: minions:planner`:
```
Quick mode (no SPEC): derive tasks from the request.
Request: <the request>
PLAN: <root>/quick/PLAN.md
Mode: <mode>
Keep small (1–3 tasks). No Covers back-refs. No goal-backward-vs-SPEC check.
```
Surface the scratch PLAN. Unless `auto` is on, pause for user confirmation before continuing.

## Step 4 — Code + review (via quick-code)

Invoke `minions:quick-code` via the Skill tool, passing `PLAN: <root>/quick/PLAN.md` (and `--auto`
if set). quick-code handles coder, reviewer-lite, and the optional fix pass. Relay its result.

## Step 5 — Dispatch the verifier (task-backward)

Agent tool, `subagent_type: minions:verifier`:
```
Quick mode (no SPEC, task-backward): verify each task in the PLAN.
PLAN.md: <root>/quick/PLAN.md
No SPEC — tasks are the contract. Re-run each task's Check; grep for stubs.
Classify each task VERIFIED/FAILED/UNCERTAIN. Do NOT update STATE.md.
```
Relay per-task verdicts verbatim.

## Hard gate

<HARD-GATE> Orchestrates only — never writes code, never commits, never reads/writes STATE.md.
Dispatches `minions:planner` and `minions:verifier` via Agent; invokes `minions:quick-code` via
Skill. All domain work belongs in those agents/skill. If writing verdicts or code here, stop.
</HARD-GATE>
