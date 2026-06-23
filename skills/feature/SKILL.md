---
name: feature
description: >-
  Use when adding a normal feature to an existing project — "build X", "implement Y", "add Z to
  this codebase". Standard tier: runs specify → architect → plan → code → verify with HITL pauses after each step. For a one-line or trivial change, use /minions:quick instead. For a greenfield project,
  use /minions:project.
argument-hint: "[request] [--auto]"
arguments:
  - request
---

# minions: feature

Announce: **"Running minions feature — routing to the next step."**

<!-- Full sequence: specify → architect → plan → code → qa → verify → review → reconcile → curate.
     Increment 3a wires: specify → architect → plan → code → verify. Remainder (qa → review → reconcile → curate) arrives in increments 3b/3c. -->

## Step 1 — Resolve root & STATE

Resolve the minions root: `.minions-root` at repo root (`path: <dir>`) overrides the default
`docs/minions/`; if it says `disabled`, stop. If `<root>/STATE.md` is missing, tell the user to
run `/minions:init` first and stop. Read STATE.md and config.yml. Apply `--auto` if passed.

## Step 2 — Determine the next step

New request (`$ARGUMENTS` non-empty, and STATE has no active feature with `Status: in progress`) → next step is `specify`.

Otherwise advance from STATE's current step: `specify → architect → plan → code → verify`.
After `verify` → stop (Step 4). Step outside this sequence → report and stop.

## Step 3 — Invoke the step skill & relay

Invoke via the Skill tool, passing `--auto` through:
`minions:specify` (with request) · `minions:architect` · `minions:plan` · `minions:code` · `minions:verify`.

Relay the step's full `Result / Summary / Next` block verbatim.

**HITL (default):** stop after one step; suggest `/minions:feature` again to advance.
**`--auto`:** loop Steps 2–3 until `verify` completes or a step returns `blocked`/`needs-input`.

## Step 4 — After verify

Tell the user: verify is the last wired step for now; qa, review, reconcile, and curate arrive in later increments. Address any FAILED acceptance criteria in `PLAN.md ## Verification` before calling this done.

## Hard gate

<HARD-GATE> Pure router only. Never dispatch an agent directly; never write specs, plans, code, or
verdicts. All domain work belongs in the step skills and their agents. If you're doing domain
reasoning here, stop.
