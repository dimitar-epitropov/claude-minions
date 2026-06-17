# minions

A Claude Code plugin: a small army of skills and agents for **spec-driven development** — a
collaborative `discuss → plan → code → verify` loop that thinks before it writes code.

The plugin also ships a few standalone skills (`explainer`, `debugger`, `idea-elaborate`). This
README is about the **dev loop** — the heart of minions.

## The idea

Most "plan the whole project up front" workflows rot: the plan is written when you know the least,
and every day of real building makes it less true. minions does the opposite. It plans **one phase
deep**, builds it, checks whether it actually delivered, and only then decides what's next — using
what it just learned. New requirements aren't a disruption; they're the normal heartbeat.

It's a deliberately small take on the same core idea as [GSD](https://github.com/) — principles
extracted, complexity left behind.

## The loop

```
   ┌──────────────────────────────────────────────────────────┐
   │                                                          ↓
 /pick → /discuss → /plan → /code → /verify → /reconcile ─────┘
```

| Step | Skill | What happens | Worker agent |
|------|-------|--------------|--------------|
| 1 | `/pick` | Choose the next phase from the backlog (or ask, if it's empty) given the north star + decisions | — (thin) |
| 2 | `/discuss` | Ask only *this* phase's open questions; lock `CONTEXT.md` | `discuss-interviewer` |
| 3 | `/plan` | Turn context into a small `PLAN.md` — tasks = atomic commits | `planner` |
| 4 | `/code` | Execute the plan, one atomic commit per task | `coder` |
| 5 | `/verify` | Goal-backward check: did the phase deliver? Write `VERIFY.md` | `verifier` |
| 6 | `/reconcile` | Fold what we learned into the backlog + decisions, then re-pick | — (thin) |

Plus two bootstrap/utility skills: `/init` (set up the loop) and `/status` (where are we?).

## Thin skills orchestrate, agents do the work

This is the core design rule, and it's why the loop stays cheap to run:

- **Skills are orchestrators.** They stay thin: read state, decide what happens next, dispatch an
  agent, relay the result, point at the next step. A skill holds almost no domain reasoning in its
  own context.
- **Agents are workers.** Each does one heavy job — research and Q&A, drafting a plan, writing
  code, verifying a goal — in its **own isolated context**. The bulky file-reading and reasoning
  never pollute the orchestrator.

Rule of thumb: if a step *reads a lot, reasons a lot, or could blow up context*, it's an agent.
That's why `discuss/plan/code/verify` dispatch agents, while `pick/reconcile/init/status` — which
only touch a handful of tiny files — run inline.

## STATE.md drives everything

State lives in **files, never in chat**. The whole loop pivots on one tiny file:

```
docs/minions/
  STATE.md        ← the single source of truth for "where are we right now"
  NORTH-STAR.md   ← goal + hard constraints + "done looks like" (~1 page, rarely edited)
  BACKLOG.md      ← flat list of candidate phases, one line each (starts EMPTY)
  DECISIONS.md    ← append-only log: date | decision | why
  phases/NNN-slug/
    CONTEXT.md    ← locked decisions for this phase only
    PLAN.md       ← task checklist; each task = 1 atomic commit + a check
    VERIFY.md     ← goal-backward checklist: did the phase deliver?
```

Every skill **reads STATE.md first** to know what to do; every agent **writes it last** when it
finishes. That makes STATE.md the handoff mechanism between steps *and* across sessions — open a
fresh session, read STATE.md, and you know exactly where the work stands and what to run next.

## How drift is killed

Four rules, enforced by the skills themselves:

1. **Plan only one phase deep.** Only the *current* phase ever gets a real `PLAN.md`.
2. **The backlog starts empty and grows on demand.** No up-front project breakdown. An empty
   backlog is the normal, healthy starting state.
3. **Reconcile is first-class.** Discovering new work mid-project is the heartbeat, handled by
   `/reconcile` adding to the backlog and re-picking — not by patching frozen plans.
4. **Decisions are append-only and separate from plans.** New requirement → append to
   `DECISIONS.md`. Plans are disposable derived views; decisions are what's durable.

## Getting started

```
/init        # bootstrap docs/minions/ and fill in the north star
/pick        # choose the first phase (it'll ask — the backlog starts empty)
/discuss     # lock the phase's context
/plan        # break it into atomic-commit tasks
/code        # build it
/verify      # did it deliver?
/reconcile   # fold in what you learned, then back to /pick
```

`/status` any time to get re-oriented.

## Repo layout

```
.claude-plugin/plugin.json   # plugin manifest
skills/                       # thin orchestrators (01-pick … 06-reconcile, init, status)
agents/                       # heavy-lifting workers (discuss-interviewer, planner, coder, verifier)
templates/                    # the tiny doc templates, including STATE.md
```

> Packaging note: `*-workspace/` directories are skill-creator scratch space — exclude them when
> distributing the plugin.
