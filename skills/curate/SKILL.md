---
name: curate
description: >-
  Use when a feature's been reconciled and the project's durable knowledge — skills, CLAUDE.md,
  rules, DECISIONS — needs updating to match what shipped, then the feature archived. "Curate the
  knowledge", "fold learnings into the skills/docs", "archive this feature", or when
  /minions:feature reaches the curate step. This is the minions curate step: normally invoked by
  /minions:feature, runnable directly.
argument-hint: "[--auto] [--apply=review|auto]"
arguments: []
---

# minions: curate

Announce: **"Running minions curate — folding durable learnings into the project's knowledge."**

## Step 1 — Resolve state & config

Resolve the minions root (`.minions-root` or default `docs/minions/`). If `<root>/STATE.md` is
missing, tell the user to run `/minions:init` first and stop.

Read `<root>/config.yml`. Extract `mode`, `auto`, `docs.knowledge`, and `curate.*` settings
(`apply` default `review`, `promote_threshold` default 3, `path` default `.claude/skills`,
`cap_lines` default 150, seed `skills.structural` and `skills.convention` lists). If `--auto` was
passed, set auto to on.

**Effective apply** = `--apply` arg if provided, else `config.curate.apply` (default `review`).

**Knowledge gate:** if `docs.knowledge` is `off`, skip curation — archive the never-curated
feature folder (same archive procedure + clean-folder precondition as Step 7; abort if dirty),
write terminal STATE (Workflow `none` / Feature `none` / Step `none` / Status "knowledge layer
off — skipped, archived" / Next `none`), relay "knowledge layer disabled; feature archived", stop.

## Step 2 — Find the active feature folder

Read STATE.md. Use the active feature folder it records. If `<feature>/SPEC.md` is missing, tell
the user to run `/minions:specify` first and stop. (ARCH.md optional — curator works from the
diff + SPEC.)

## Step 3 — Phase detection (STATE is the authoritative signal, NOT the working tree)

Read STATE. If STATE Step is `curate` with **Status `staged — awaiting approval`** (a prior
`apply: review` pass already staged edits + wrote CURATE.md and paused), this is the **approval
re-invocation** → skip straight to Step 7 (Finalize) and **do NOT re-dispatch the curator** —
re-dispatching would re-mine the diff and double-increment the ledger. Otherwise this is a fresh
run → continue to Step 4.

Do not infer "approved" from the working tree — under `apply: auto` a gated root `CLAUDE.md` edit
is intentionally left staged; STATE is the only reliable signal.

## Step 4 — STATE ownership (in-progress)

Update `<root>/STATE.md`: set Step to `curate`, Status to `in progress`, Next to `/minions:curate`
(self), Updated to today. This ensures an interrupted run is resumable.

## Step 5 — Dispatch the curator

Use the Agent tool with `subagent_type: minions:curator`. Pass a self-contained prompt:

```
Feature folder: <abs path>
Mode: <maintain|vibe>
Apply: <review|auto>
SPEC.md: <abs path>   ARCH.md: <abs path if present>
Git diff: <the feature's commit range / changed files>
knowledge-ledger.md: <abs path to <root>/knowledge-ledger.md>
curate config: promote_threshold=<n>, path=<curate.path>, cap_lines=<n>,
  seed structural=<list>, seed convention=<list>
```

The curator stages edits, updates the ledger, writes `<feature>/CURATE.md`, and returns its
findings. It commits nothing and archives nothing.

**If effective apply is `review` (default):** do not commit, do not archive. Relay
`<feature>/CURATE.md` + the staged diff (`git status` / `git diff --staged`). Set STATE: Step
`curate`, **Status `staged — awaiting approval`**, Next `/minions:curate`, Updated today.
**Pause** — tell the human: review staged edits and re-run `/minions:curate` to approve (the step
commits + archives; no manual `git commit`), or pass `--apply=auto` to do it now. Stop here.

**If effective apply is `auto`:** fall straight through to Step 7 (Finalize).

## Step 7 — Finalize: commit + archive + terminal STATE

**Commit the curator's non-gated staged edits:** `git add` exactly the surface files listed in
`<feature>/CURATE.md ## Staged edits` + `<root>/knowledge-ledger.md` + `<feature>/CURATE.md`;
`git commit -m "chore(knowledge): curate <NNN-slug>"`; `git push`.
**Never `git add` the root `CLAUDE.md` / orientation-pointer edit** — it is always human-gated,
even under `auto`; leave it staged/unstaged in the tree and surface it.

**Archive** (precondition: nothing in the feature folder is left staged — root `CLAUDE.md` is
outside the folder so the folder can be clean): `mkdir -p <root>/features/archive`; `git mv
<root>/features/<NNN-slug> <root>/features/archive/<NNN-slug>` (fall back to `mv` if not
git-tracked); commit + push the move. **If `git status` shows uncommitted/untracked files inside
the feature folder, abort the move** with a clear message (do not archive a dirty folder).

**Terminal STATE:** Workflow `none`, Feature `none`, **Step `none`** (workflow done; record curate
completion in Status), Status one line (e.g. "feature shipped — 3 skills refreshed, 1 convention
promoted; archived"), Updated today.
**If a gated root `CLAUDE.md` edit remains staged**, set **Open** to "root CLAUDE.md edit staged
— review and commit it" and **Next** to that action (do NOT set Next `none` and strand it);
otherwise Next `none` (feature shipped).

Relay CURATE.md + any gated root `CLAUDE.md` edit, and the curator's last `Result / Summary /
Deviations-Warnings` block verbatim.

## Hard gate

<HARD-GATE> This skill orchestrates + finalizes only. It dispatches **only** `minions:curator` —
nothing else. All knowledge reasoning and authoring belongs to the curator; this step's own writes
are limited to git and terminal STATE. It **never** authors skills/CLAUDE.md/rules itself; it
**never** commits root `CLAUDE.md` or orientation-pointer edits unattended — always gated.
</HARD-GATE>
