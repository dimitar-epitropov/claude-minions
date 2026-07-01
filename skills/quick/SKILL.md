---
name: quick
description: >-
  Use when the change is a one-liner / small edit / PR-comment fix / follow-up to a shipped feature
  — `/minions:quick "…"`. Discipline (atomic commits, a review, a doc nudge) without paperwork (no
  SPEC, no feature folder). If the change spans multiple modules or introduces a new pattern, use
  /minions:feature instead.
argument-hint: "[request] [--plan] [--auto]"
arguments:
  - request
---

# minions: quick

Announce: **"Running minions quick."**

## Step 1 — Resolve root & config (NOT STATE)

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, stop. Otherwise default to `docs/minions/`.

Read `<root>/config.yml` (for `auto`). Do not touch STATE — quick is stateless by design.

Parse flags: `--plan` (planning mode), `--auto` (skip HITL pauses).

## Step 2 — Route

- **No `--plan` (default):** invoke `minions:quick-code` via the Skill tool, passing the request
  and `--auto` if set.

- **`--plan`:** `--plan` not yet available — running plain quick. Fall through to `minions:quick-code`
  as above. *(Task 4 will wire in `minions:quick-plan`.)*

## Step 3 — Relay & stop

Relay the step skill's full result verbatim and stop. `--auto` changes nothing at the router
level — the step handles its own pauses.

## Hard gate

<HARD-GATE> Pure router only. Never dispatch an agent directly — no Agent tool calls, no direct
agent dispatch of any kind. Never write specs, plans, code, or verdicts. Never read or write
STATE.md. All domain work belongs in the step skills. If you are doing domain reasoning here, stop.
</HARD-GATE>
