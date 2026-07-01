---
name: review
description: >-
  Use when a feature's been verified and the diff needs a compliance + quality review before
  reconcile — "review this feature", "check spec compliance", "assess the diff", or when
  /minions:feature reaches the review step. This is the minions review step: normally invoked by
  /minions:feature, but runnable directly to (re)review the active feature without restarting the
  workflow.
argument-hint: "[--auto] [--review-fix=auto|manual|off]"
arguments: []
---

# minions: review

Announce: **"Running minions review — checking the diff for spec-compliance, then quality."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode`, `auto`, `skills.reviewer`, `skills.coder`,
`config.loops.review_fix`, and `config.loops.max_iters` (default 3). If `--auto` was passed, set
auto to on.

Effective review-fix mode = `--review-fix` arg if provided, else `config.loops.review_fix`,
defaulting to `manual`.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/SPEC.md` does not exist, tell the user to run `/minions:specify` first and stop.
If `<feature>/PLAN.md` does not exist, tell the user to run `/minions:plan` first and stop.

**STATE ownership (in-progress):** update STATE.md now, before dispatch: set Step to `review`,
Status to `in progress`, Next to `/minions:review` (self), Updated to today. This ensures an
interrupted run is resumable.

## Step 3 — The review-fix loop

Build the reviewer skill-pack line from `skills.reviewer`: if non-empty, include the line
`"before stage 2, invoke and obey these skills: <skills.reviewer list>"`; if empty, omit it.

**Initial reviewer dispatch:** Use the Agent tool with `subagent_type: minions:reviewer`. Pass a
self-contained prompt containing:

```
Feature folder: <absolute path to feature folder>
Mode: <mode>
SPEC.md: <absolute path to SPEC.md>
Git diff: <the feature's commit range or changed files — name what was changed>
stage: both
lite: false
<reviewer skill-pack line, if non-empty>
```

Take the findings from the reviewer's return block (Critical/Important/Minor with file:line). The
reviewer writes no STATE and no files.

### Branch on effective review-fix mode:

**off — no fixing:**

Do not dispatch the coder; continue to Step 4 (terminal STATE write), then Step 5 relays the findings.

**manual (default) — one fix pass:**

Append all **Minor** findings (and any Critical/Important you are not fixing) to
`<feature>/PLAN.md ## Warnings` — one bullet each; replace the `_None yet._` line if it is still
present.

If there are **Critical or Important** findings, re-dispatch the coder **once**:

Use the Agent tool with `subagent_type: minions:coder`. Pass a self-contained prompt:

```
Feature folder: <absolute path to feature folder>
PLAN.md: <absolute path to PLAN.md>
Skill pack: <skills.coder list, if non-empty>

You are applying review fixes — NOT executing the plan. Fix exactly the findings listed below,
one atomic commit per finding, log each fix to PLAN.md ## Deviations (dated). Do not change
anything the findings do not name.

Findings to fix:
<paste the Critical and Important findings from the reviewer's return block>
```

**Then stop the loop** — manual means one checked pass; the human is the outer loop. Any residual
Critical/Important findings after the fix pass are surfaced in the relay (Step 5).

**auto — loop to max_iters with stall-stop:**

Initialize `prev_unresolved = ∞`. Loop up to `max_iters` iterations:

1. Dispatch `minions:reviewer` (same prompt as the initial dispatch above).
2. Append this pass's **Minor** findings to `<feature>/PLAN.md ## Warnings`.
3. If Critical/Important count == 0: exit the loop (clean).
4. If Critical/Important count `>= prev_unresolved`: stop early — stall detected (no progress).
5. Set `prev_unresolved = Critical/Important count`. Re-dispatch `minions:coder` with the same
   fix prompt as in the manual branch, passing this iteration's Critical/Important findings.

After the loop exits (clean, cap hit, or stall), surface any residual Critical/Important findings
in the relay.

## Step 4 — Terminal STATE write (this step owns it)

After the loop settles, **this step writes `<root>/STATE.md`** (the canonical schema — `## Now`/`## Next`/`## Open`), overwriting any STATE the fix-coder left (the coder writes `Step code` / `Next /minions:verify`, which is wrong here): set **Step** to `review` (bare token), **Status** to a one-line summary (e.g. "review clean" or "2 Important fixed, 1 Minor noted"), **Next** to `/minions:reconcile`, and **Updated** to today.

## Step 5 — Relay & pause

Relay the reviewer's last `Result / Summary / Deviations-Warnings` block verbatim. Surface
`<feature>/PLAN.md ## Warnings` (and `## Deviations` if fixes were applied).

Unless `auto` is on, **stop here** and suggest `/minions:reconcile` as the next step. Wait
for the user to proceed.

If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> This skill orchestrates only. It never reviews the diff itself, never writes findings
as its own judgment, and never fixes code. It dispatches **only** `minions:reviewer` and
`minions:coder` (for fixes) — nothing else. All review reasoning belongs to the reviewer; all
fixing to the coder. If you find yourself writing compliance verdicts or quality findings here,
stop: those belong in the dispatch prompt as context, not as output.
</HARD-GATE>
