---
name: plan
description: >-
  Use when a feature's SPEC (and ARCH, if it exists) is settled and needs to be turned into an
  executable task list — "plan this feature", "break the spec into tasks", re-planning the active
  feature, or when /minions:feature reaches the plan step. This is the minions plan step: normally
  invoked by /minions:feature, but runnable directly to (re)write the active feature's PLAN.md
  without restarting the workflow.
argument-hint: "[--auto] [--plan-check=auto|manual|off]"
arguments:
  - name: --plan-check
    values: [auto, manual, off]
    description: Override config.loops.plan_check for this run.
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
[ARCH.md: <absolute path to ARCH.md> — include this line ONLY if <feature>/ARCH.md exists; omit it entirely otherwise]

Read these files (and nothing beyond what is listed here):
- <root>/PRODUCT.md
- <root>/TECH.md
- <list the real files/modules the feature will touch — read SPEC.md Goals/ACs to identify them>
```

The architect step normally creates ARCH.md, so it usually exists; the bracket annotation in the fence handles both cases.

Do NOT plan the feature yourself. Do NOT write PLAN.md yourself. That is the planner's job.

## Step 4 — Plan-check loop

Determine the effective `plan_check` from `--plan-check` else `config.loops.plan_check` (read in Step 1; default `manual`); `max_iters` from `config.loops.max_iters` (default 3).

**off:** skip this step entirely — the single planner pass from Step 3 stands.

**manual — one checked pass:**

Dispatch `subagent_type: minions:verifier` with a self-contained prompt:

```
mode: plan
Feature folder: <absolute path to feature folder>
SPEC.md: <absolute path>
PLAN.md: <absolute path>

Check the plan goal-backward (coverage, grounding, provability). Return criticals and warnings
in your return block. Do NOT write ## Verification and do NOT update STATE.md.
```

Take the returned criticals and warnings from the verifier's return block.

Append each warning as a bullet to `PLAN.md ## Warnings` (replace the `_None yet._` line if
it's still present).

If there are criticals, re-dispatch `minions:planner` once with the original planner context
(feature folder, mode, SPEC.md, ARCH.md if present, product/tech files) plus:

```
The plan-check verifier found these criticals — fix them. For anything you cannot fix,
document it as a ## Warnings entry in PLAN.md:
<paste criticals list>
```

Then stop the loop — manual means one checked pass; the human is the outer loop. If criticals
remain after the replanner pass, surface them in the relay (Step 5).

**auto — loop to max_iters with stall-stop:**

Initialize `prev_critical_count = ∞`. Loop up to `max_iters` iterations:

1. Dispatch `minions:verifier` (same prompt as manual above).
2. Append this pass's warnings to `PLAN.md ## Warnings`.
3. If criticals == 0: exit the loop (clean).
4. If `len(criticals) >= prev_critical_count`: stop early — stall detected (no progress).
5. Set `prev_critical_count = len(criticals)`. Re-dispatch `minions:planner` with the same
   critical-fix prompt as in the manual branch.

After the loop exits (clean, cap, or stall), surface any residual criticals in the relay.

## Step 5 — Relay & pause

Relay the agent's `Result / Summary / Next` block verbatim and surface the path to `PLAN.md`. Unless `auto` is on, stop and suggest `/minions:code` as the next step. If `auto` is on, state the next step and continue.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never writes PLAN.md content, never analyses the
spec, and never dispatches any agent other than `minions:planner` and `minions:verifier` (plan
mode only) — nothing else. All domain reasoning — the task breakdown, grounding, the goal-backward
check — belongs to the agents. If you find yourself writing plan content here, stop: put it in the
dispatch prompt as context, not as output.
</HARD-GATE>
