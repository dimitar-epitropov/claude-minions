---
name: architect
description: >-
  Use when a feature's SPEC is settled and needs its patterns/mechanisms decided before planning —
  "design the architecture", "scout the codebase for patterns", "produce ARCH.md", or when
  /minions:feature reaches the architect step. This is the minions architect step: normally invoked
  by /minions:feature, but runnable directly to (re)write the active feature's ARCH.md without
  restarting the workflow.
argument-hint: "[--mode=scout|design] [--auto]"
arguments: []
---

# minions: architect

Announce: **"Running minions architect — choosing the patterns and mechanisms."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode`, `auto`, and `skills.architect` (the role's skill pack). If `--auto` was passed, set auto to on.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/SPEC.md` does not exist, tell the user to run `/minions:specify` first and stop.

**STATE ownership — this skill's only STATE write:** update STATE.md now, before dispatch: set Step
to `architect`, Status to `in progress`, Next to `/minions:architect` (self), Updated to today.
This ensures an interrupted run is resumable. Do NOT write a "done" status here — the architect
agent writes the end-of-run STATE update (Step `architect` → done, Next: `/minions:plan`) at the
end of its run.

## Step 3 — Dispatch the architect

Resolve the architect mode: if `--mode=scout` or `--mode=design` was passed, use that value;
otherwise default from the project `mode` — `maintain → scout`, `vibe → design`.

Use the Agent tool with `subagent_type: minions:architect`. Pass a self-contained prompt containing
everything the agent needs — it must not hunt:

```
Feature folder: <absolute path to feature folder>
Mode: <scout|design>
SPEC.md: <absolute path to SPEC.md>
TECH.md: <absolute path to <root>/TECH.md>
Before working, invoke and obey these skills: <config.skills.architect pack, comma-separated>
Read these files (and nothing beyond what is listed here):
- <root>/PRODUCT.md
- <root>/TECH.md
- <list the real files/modules the feature will touch — read SPEC.md Goals/ACs to identify them>
```

Omit the "invoke and obey" line entirely if `config.skills.architect` is empty or absent.
Instruct: write ARCH.md, do not write code.

Do NOT scout the codebase yourself. Do NOT write ARCH.md yourself. That is the architect's job.

## Step 4 — Relay & pause

When the agent returns, relay its full `Result / Summary / Next` block verbatim. Surface the path
to `ARCH.md` so the user can open it. (The agent has already written the end-of-run STATE update.)

Unless `auto` is on, **stop here** — tell the user the architecture is ready for review and suggest
`/minions:plan` as the next step. Wait for them to proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never scouts the codebase, never writes ARCH.md, and
never dispatches any agent other than `minions:architect`. All domain reasoning — the pattern
search, the mechanism choices, the ARCH prose — belongs to the agent. If you find yourself writing
architecture content here, stop: put it in the dispatch prompt as context, not as output.
