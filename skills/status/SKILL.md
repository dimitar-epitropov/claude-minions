---
name: status
description: >-
  Use when you need to re-orient in a minions project — "where are we", "what's next", "minions
  status", "what should I run next", or when resuming work in a fresh session. Reads
  docs/minions/STATE.md (and the active feature folder) and reports the one next action.
  Pure reporting — changes nothing.
---

# minions: status

You give a fast, honest "you are here." This is **pure reporting** — read state, don't change it,
don't dispatch agents, don't re-derive from git.

## What to do

1. Resolve the minions root (`.minions-root` if present, else `docs/minions/`). Read
   `<root>/STATE.md`. If it's missing, this project isn't initialized — say so, suggest
   `/minions:init`, and stop.
2. Glance — only as needed for an accurate report:
   - `<root>/config.yml` — `mode`, `auto`, `guard` (so you can note how the project is set up).
   - The active feature folder `<root>/features/<NNN-slug>/` — which artifacts exist
     (`SPEC.md`? `ARCH.md`? `PLAN.md`? a `## Verification` section in PLAN?). Their presence is
     the real signal of how far the feature has gotten, and a cross-check on STATE's claim.
3. Report compactly — lead with the one-liner, then detail:

```
Workflow: <feature | quick | none>   Mode: <maintain|vibe>   Guard: <soft|hard|off>
Feature:  <NNN-slug or "none">
Step:     <current step> — <status>
Next:     <the single next action — name the skill to run>
Open:     <open threads / blockers, or "none">
```

4. End by naming the **one** next thing to run and why. Map step → next step for the `feature`
   spine: specify → architect → plan → code → qa → verify → review → reconcile → done. If no
   workflow is active, the next action is `/minions:feature` (normal feature) or `/minions:quick`
   (small edit).

## Keep it honest

STATE.md is the source of truth and is deliberately tiny, so this stays cheap. If STATE looks
stale or **contradicts** the artifacts on disk (e.g. it says "plan" but `PLAN.md` doesn't exist,
or a feature looks done but STATE says mid-flight), say so plainly and suggest the step that would
set it right — don't silently guess a state.
