---
name: quick-code
description: >-
  Use when the minions quick code step needs to run — a small, focused change request that doesn't
  need a feature folder or SPEC/PLAN: "make this change quickly", "quick-code this", or when
  /minions:quick reaches the code step. Normally invoked by /minions:quick.
argument-hint: "[request] [--auto]"
arguments:
  - request
---

# minions: quick-code

Announce: **"Running minions quick — code, review, done."**

## Step 1 — Resolve config only (NOT STATE)

Resolve the minions root: if `.minions-root` exists at repo root with `path: <dir>`, use that dir;
if it says `disabled`, tell the user minions is disabled here and stop; otherwise default to
`docs/minions/`.

Read `<root>/config.yml`. If `config.yml` does not exist, minions isn't initialized here — tell
the user to run `/minions:init` and stop.

Extract `mode`, `auto`, `skills.coder`, and `skills.reviewer`. If `--auto` was passed, set auto
to on.

**Global Constraint — stateless:** quick-code does NOT read or write STATE.md. This is a
deliberate exception: it keeps quick unobstructable by any feature-spine state. If a change
deserves STATE tracking, use `/minions:feature`.

## Step 2 — Scope-check (inline, ask-once)

**Skip this step entirely** when a scratch PLAN path was passed (invoked by `quick --plan` — that
route already committed to quick mode).

Judge the request: does it plausibly span **multiple modules** or **introduce a new
pattern/dependency**? If clearly small, say nothing and proceed.

If yes and `auto` is off, ask once:
> "This looks like it may want `/minions:feature` (it <reason>). Continue in quick, or switch?"

Honor the answer: switch → tell them to run `/minions:feature "<request>"` and stop; continue →
proceed. Never silently refuse.

If `auto` is on and the signal is present, note it in the relay and proceed.

## Step 3 — Dispatch the coder

Build the skill-pack line from `skills.coder`:
- Non-empty: `Before coding, invoke and obey these skills: <comma-separated list>`
- Empty: `Before coding, note: no project skill-packs configured`

Use the Agent tool with `subagent_type: minions:coder`. Pass a self-contained prompt:

If a scratch PLAN path was passed (from `quick --plan`):
```
PLAN.md: <path>
Mode: <mode>
<skill-pack line>
Quick mode (stateless): do NOT update STATE.md — this is a quick run with no feature STATE; report commits in your return block only.
```

Otherwise (direct change — quick mode):
```
Quick mode (no PLAN): make this change as a single atomic task.
Change: <the request>
Mode: <mode>
<skill-pack line>
Quick mode (stateless): do NOT update STATE.md — this is a quick run with no feature STATE; report commits in your return block only.
```

Do not implement or commit anything here — that is the coder's job.

## Step 4 — Dispatch the reviewer (lite)

After the coder returns `ok`, build the reviewer skill-pack line from `skills.reviewer`. If the
coder returns `blocked` or `needs-input`, relay its block verbatim and STOP — do not proceed to
the reviewer.

Use the Agent tool with `subagent_type: minions:reviewer`. Pass a self-contained prompt:

```
Mode: <mode>
Intent (no SPEC): <the request>
Git diff: <the coder's commit range / changed files>
stage: both
lite: true
<reviewer skill-pack line, if non-empty>
```

From the reviewer's findings: if there are **Critical/Important** findings and `auto` is off, offer
one coder fix pass (re-dispatch `minions:coder` in quick mode: "fix exactly these findings, one
atomic commit each; change nothing else"). In `auto`, apply the one fix pass automatically.
**Minor** findings are listed only. Never loop more than one fix pass.

## Step 5 — doc-touch (inline micro-reconcile)

Judge whether the change clearly establishes or breaks a convention worth recording (a new pattern,
a naming/style choice, a structural fact). If not, **stay silent**.

If yes: propose a concrete edit to the right native surface (per-dir `CLAUDE.md` / `.claude/rules/*`
— never `docs/minions/**`). Ask first before writing. Root `CLAUDE.md` is **always** gated (ask
even under `--auto`). Other surfaces auto-apply under `--auto`. Keep it to the one surface the
learning belongs on. No curator, no RECONCILE.md.

## Step 6 — Relay & stop

Relay the coder's and reviewer's `Result/Summary/Deviations` blocks verbatim. Surface the commits
made and any residual findings. This is the single natural stopping point.

## Hard gate

<HARD-GATE> quick-code orchestrates only. It never writes code, never makes commits, and never reads
or writes STATE.md. It dispatches only `minions:coder` and `minions:reviewer`. Scope-check asks
once — it never refuses. doc-touch asks before writing and stays silent when nothing is clearly
earned. If you find yourself implementing changes or routing to any agent other than coder/reviewer,
stop.
</HARD-GATE>
