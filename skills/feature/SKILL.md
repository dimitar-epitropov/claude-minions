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
     Currently wired: specify → architect → plan → code → verify → review → reconcile → curate. qa is intentionally skipped (deferred — see the inc-3c plan). Spine is now complete. -->

## Step 1 — Resolve root & STATE

Resolve the minions root: `.minions-root` at repo root (`path: <dir>`) overrides the default
`docs/minions/`; if it says `disabled`, stop. If `<root>/STATE.md` is missing, tell the user to
run `/minions:init` first and stop. Read STATE.md and config.yml. Apply `--auto` if passed.

## Step 2 — Determine the next step

New request (`$ARGUMENTS` non-empty, and STATE has no active feature with `Status: in progress`) → next step is `specify`.

Otherwise advance from STATE's current step: `specify → architect → plan → code → verify → review → reconcile → curate`.
After `curate` → stop (Step 4). Step outside this sequence → report and stop.

## Step 3 — Invoke the step skill & relay

Invoke via the Skill tool, passing `--auto` through:
`minions:specify` (with request) · `minions:architect` · `minions:plan` · `minions:code` · `minions:verify` · `minions:review` · `minions:reconcile` · `minions:curate`.

Relay the step's full `Result / Summary / Next` block verbatim.

**HITL (default):** stop after one step; suggest `/minions:feature` again to advance.
**`--auto`:** loop Steps 2–3 until `curate` completes or a step returns `blocked`/`needs-input`.

## Step 4 — After curate

The spine is complete: the feature has been reconciled, knowledge curated, and the folder archived.
Address any FAILED acceptance criteria in `PLAN.md ## Verification` before calling this done.

## Hard gate

<HARD-GATE> Pure router only. Never dispatch an agent directly; never write specs, plans, code, or
verdicts. All domain work belongs in the step skills and their agents. If you're doing domain
reasoning here, stop.
