---
name: reconcile
description: >-
  Use when a feature's been reviewed and its SPEC/ARCH need folding to what actually shipped before
  the knowledge pass — "reconcile the spec", "update SPEC/ARCH to the real diff", or when
  /minions:feature reaches the reconcile step. This is the minions reconcile step: normally invoked
  by /minions:feature, runnable directly to fold the active feature's spec without restarting the
  workflow.
argument-hint: "[--auto]"
arguments: []
---

# minions: reconcile

Announce: **"Running minions reconcile — folding SPEC and ARCH to what actually shipped."**

## Step 1 — Resolve state & config

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`. If `<root>/STATE.md` is missing, tell the user to run `/minions:init` first and
stop. Read `<root>/config.yml`. Extract `mode` and `auto`. If `--auto` was passed, set auto to on.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records.

If `<feature>/SPEC.md` does not exist, tell the user to run `/minions:specify` first and stop.
If `<feature>/ARCH.md` does not exist, note it and continue — the architect step may have been
skipped; reconcile folds only what exists.
If `<feature>/PLAN.md` does not exist, tell the user to run `/minions:plan` first and stop.

**STATE ownership (in-progress):** update STATE.md now: set Step to `reconcile`, Status to
`in progress`, Next to `/minions:reconcile` (self), Updated to today.

## Step 3 — Reconcile inline (the work — no agent dispatch)

Read the feature's `git diff` (its commit range / changed files), `SPEC.md`, and `ARCH.md`.

Edit **SPEC.md** in place: update the Goal and `AC-n` entries so they describe what was actually
built. A deviation that changed behavior updates the AC; an AC that was dropped is marked (e.g.
`[dropped]`), not deleted. Edit **ARCH.md** in place (if it exists): update patterns,
new-elements, and libraries to match the real diff — a swapped library, a changed pattern.

These two files are feature-local and about to be archived — edit them directly. Keep edits
truthful and minimal: reconcile makes the *spec* match *reality*, not the reverse (design
principle 4). This step does not touch durable knowledge (skills, CLAUDE.md, rules, DECISIONS) —
that is the curator's job. It does not emit RECONCILE.md. It does not archive the feature folder.

## Step 4 — Terminal STATE write (this inline step owns it)

Write `<root>/STATE.md` (canonical schema — `## Now`/`## Next`/`## Open`): set **Step** to
`reconcile` **done**, **Status** to a one-line summary (e.g. "SPEC/ARCH folded to diff: 1 AC
updated, lib note refreshed"), **Next** to `/minions:curate`, and **Updated** to today.

## Step 5 — Relay & pause

Summarize what changed in SPEC.md and ARCH.md (which ACs were updated, which patterns changed).
Unless `auto` is on, **stop here** and suggest `/minions:curate` as the next step. Wait for the
user to proceed. If `auto` is on, state the next step and continue without waiting.

## Hard gate

<HARD-GATE> reconcile folds **only** SPEC.md and ARCH.md (the feature-local, about-to-be-archived
pair). It never writes durable knowledge (skills, CLAUDE.md, rules, DECISIONS — that is the
curator). It does not emit RECONCILE.md. It never archives the feature folder. It never rewrites
reality to match the spec — only the spec to match reality. If a learning feels durable, note it
for curate, not here.
</HARD-GATE>
