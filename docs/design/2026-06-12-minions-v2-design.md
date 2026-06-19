# minions v2 — Framework Design

**Date:** 2026-06-12 · **Last revised:** 2026-06-18 · **Status:** approved design, pre-implementation
**Supersedes:** the v1 loop (`01-pick … 06-reconcile`) — clean restructure, proven pieces ported.

minions is a Claude Code plugin for **spec-driven development sized to the task**: a small,
knowable system of workflows, steps, and agents that keeps the discipline of heavyweight
frameworks (GSD, BMAD, spec-kit) without their ceremony. It is single-player: artifacts are
written for one developer + Claude, not a team.

---

## 1. Vision and non-goals

**Vision.** Every change to a codebase — a one-line fix or a greenfield project — enters through
a workflow that fits its size. The workflow guarantees the non-negotiables (spec where it
matters, atomic commits, verification against acceptance criteria, docs that match reality)
while the *amount* of process scales with the work. State lives in files, so any session can
resume anywhere. The owner can hold the whole framework in their head.

**Non-goals** (each one is a documented failure mode of an existing framework — see §11):

- **No global ID registries.** No CR-01/DF-03 cross-document matrices. IDs exist only *inside*
  one feature's folder and die when it archives.
- **No persona theater.** Agents are functions with one job, not characters. There is no
  "Manager" agent — the thin skills plus `STATE.md` are the manager.
- **No plan-the-whole-project.** Plans are one feature deep, written when we know the most.
- **No markdown sea.** A small fixed set of capped files per feature; caps flag bloat (§7);
  no document whose only job is to relay another's contents — TECH.md is the one deliberate,
  capped exception, a thin index into native surfaces (§11.19).
- **No mandatory ceremony.** Human-in-the-loop pausing (with `--auto` to skip it), question
  counts, loops, and the guard are configurable, not law.

---

## 2. Design principles

1. **Skills orchestrate, agents work.** Anything that reads a lot, reasons a lot, or could blow
   up context runs in an agent with a fresh window; orchestrators route and relay. *(GSD,
   Anthropic context-engineering guidance — §11.1)*
2. **State in files, never in chat.** `STATE.md` is read first by every skill and written last
   by every agent; a fresh session resumes from disk alone. *(GSD STATE.md, minions v1 — §11.2)*
3. **Right-size the process.** Tiered workflows (`quick` / `feature` / `project`) with explicit
   upgrade signals. The bazooka is never the only gun. *(the genre's #1 complaint; open niche —
   §11.10)*
4. **Specs converge to reality, not the reverse.** Implementation always deviates; the reconcile
   step folds reality back into spec, plan, and steering docs every cycle. *(OpenSpec
   archive-merge, community same-PR rule — §11.9)*
5. **Verification is adversarial and mechanical.** The verifier distrusts completion claims and
   checks numbered acceptance criteria against actual code. *(GSD goal-backward verification +
   Kiro EARS criteria — §11.4, §11.5)*
6. **Guidelines always, ceremony optionally.** Best practices live in agents (always on);
   process lives in skills and config (dialable). "Lite" means fewer steps, never worse steps.
7. **Convention over schema.** Agents share a fixed return format and fixed artifact paths; no
   JSON contracts until automation demands them.
8. **Steer before blocking.** Hooks inject context first, deny only when config says so.
   *(Claude Code 2026 `additionalContext` pattern — §11.16)*
9. **The framework eats its own feedback.** Friction is captured the moment it happens
   (`/minions:feedback`) and becomes eval cases and skill edits later. *(superpowers
   writing-skills TDD — §11.18)*

---

## 3. Architecture: three layers, fixed depth

```
WORKFLOW SKILLS        /minions:feature  /minions:quick  /minions:project ...
  thin routers          read STATE + config → invoke next STEP skill → relay
       │                ≤ ~40 lines, zero domain logic
       ▼
STEP SKILLS            /minions:specify  /minions:plan  /minions:code ...
  step orchestrators    resolve config (auto/loops/depth/skill-packs)
       │                build self-contained dispatch prompt → dispatch agent(s)
       │                own the loop (e.g. plan ⇄ check) and the HITL pause
       │                ≤ ~80 lines, zero domain reasoning
       ▼
AGENTS                 specificator, architect, planner, coder, qa, verifier ...
  fresh-context         do the actual reading/reasoning/writing
  workers               write artifacts + STATE.md, return distilled summary
       │
       ▼
ARTIFACTS              docs/minions/** — the only memory that matters
```

**Why a step-skill layer at all** (this is the one piece of GSD's command→workflow→agent
stack we keep): loop logic and pause logic must live somewhere that is (a) shared across
workflows and (b) outside the agent — an agent cannot re-dispatch itself with fresh context,
because subagents can't spawn subagents. The step skill is that home. `feature`, `quick`, and
`project` all reuse the same `/minions:plan` step; improving planning is one edit.

**Anti-bloat rules (hard):**

- Depth is exactly 3. A step skill never invokes another step skill. A workflow never
  dispatches an agent directly.
- Line caps above are enforced at review time; exceeding them means logic is in the wrong layer.
- Workflows differ *only* in which steps run and with which depth knobs — never in how a step
  works.
- Steps are individually invocable by the user (`/minions:plan` alone re-runs planning for the
  active feature), which is what makes any workflow resumable mid-flight.

**Claude Code mechanics** (2026 — see §11.12 for sourcing): everything ships as `skills/`
(`commands/` is legacy). Step skills stay model-invocable so workflow skills can call them via
the Skill tool; their descriptions are written as triggers ("Use when…") per the CSO rule, with
a note that they are normally invoked by minions workflows. Agents live in `agents/` and are
namespaced `minions:<name>`. Plugin-shipped agents cannot carry `permissionMode`/`hooks` —
enforcement therefore lives exclusively in plugin-level `hooks/hooks.json`.

---

## 4. Workflows (the tiers)

| Tier | Skill | Steps | Use it for |
|---|---|---|---|
| Quick | `/minions:quick` | (plan*) → code → review-lite → doc-touch (* with `--plan`: + verify) | PR comments, small edits, follow-ups to a built feature |
| Standard | `/minions:feature` | specify → architect → plan → code → qa → verify → review → reconcile → curate | a normal feature on an existing project |
| Project | `/minions:project` | brainstorm → scope → PRODUCT/TECH bootstrap → loops `/minions:feature` per backlog item | greenfield vibe-coded project *(built in step 6)* |
| — | `/minions:debug` | hypothesis loop via debugger agent | bugs *(later)* |
| — | `/minions:research` | structured deep-dive via researcher agent | tech choices, deep dives *(later)* |
| — | `/minions:inspect` | read-only assessment of current implementation | evaluating vibe-coded project state *(later)* |
| — | `/minions:refactor` | shape TBD after feature flow proves itself | refactorings *(later)* |

**Right-sizing signals are explicit, both directions.** `quick` checks scope first: if the
change spans multiple modules or introduces a pattern, it says *"this wants
`/minions:feature`"* and stops. `feature`'s specificator, on a trivial request, says *"this
wants `/minions:quick`"*. Inspired by Taskmaster's complexity scoring (§11.10), implemented as
judgment + stated criteria, not a numeric score.

**`/minions:feature` — the v1 spine, step by step:**

1. **specify** → specificator agent. Interview (≤ N questions per config), writes
   `SPEC.md`: goal, numbered acceptance criteria, clarifications log, out-of-scope.
2. **architect** → architect agent (maintain mode default = *pattern scout*). Writes `ARCH.md`:
   which existing patterns to follow (real paths), what's genuinely new and how, libraries.
   May dispatch the researcher for online evidence. In maintain mode this is often 10 lines —
   that's success, not laziness.
3. **plan** → planner agent, then the **plan-check loop**: verifier (plan mode) reviews
   coverage/groundedness; criticals are fixed by re-dispatching the planner with the findings;
   warnings append to PLAN.md `## Warnings`. Governed by `loops.plan_check` (§8): `manual`
   (default) = one checked pass, then you re-run for more; `auto` = the step loops up to
   `loops.max_iters` with stall-stop. Output `PLAN.md`: 2–7 tasks, each = one atomic commit + a
   runnable check + `covers: AC-n` back-refs.
4. **code** → coder agent. Task-by-task, one commit per task, runs each task's check,
   deviation rules (§11.6) with every deviation logged into PLAN.md.
5. **qa** → qa agent. Audits and extends tests against the ACs (every AC has a failing-able
   test; quality of assertions; missed edge cases from SPEC). Commits test improvements.
6. **verify** → verifier agent (code mode). Goal-backward: derives what must be TRUE → EXIST →
   WIRED from SPEC's ACs, greps for stubs, runs checks, distrusts the coder's summary. Verdict
   per AC into PLAN.md `## Verification`.
7. **review** → reviewer agent, two-stage: spec-compliance first (built what was asked, nothing
   more), then code quality — where config skill packs fire (e.g. `java-stack:java-review`).
8. **reconcile** → inline in the step skill (cheap, no agent): diff SPEC + ARCH against the
   real `git diff` and update *those two* to reality (they're feature-local, disposable, about
   to be archived — so reconcile edits them directly). Then hand off to `curate` — reconcile no
   longer emits knowledge suggestions and no longer archives (both moved to the curator).
9. **curate** → curator agent (the knowledge librarian). Owns the entire durable-knowledge layer:
   classifies each durable learning by *trigger type* and routes it to the surface that loads it at
   the right moment (§11.19), refreshes structural facts from source and promotes recurring
   conventions past a support threshold (default 3), writes the edits (`apply: review` pauses for
   approval, `auto` commits; root `CLAUDE.md` always gated), updates the cross-feature
   `knowledge-ledger.md`, and finally archives the feature folder. Full mechanism:
   `2026-06-18-knowledge-curator-design.md`.

By default the workflow pauses after every step, relays the result, and suggests the next one
for you to launch (§8); `--auto` runs the steps back-to-back.

**`/minions:quick`:** scope check inline → coder (same skill packs, same atomic-commit rule) →
reviewer single-stage → doc-touch (micro-reconcile: propose a `CLAUDE.md`/rule update *if* the
change warrants, ask first). `--plan` inserts plan before code and verify after. No SPEC, no feature folder —
discipline without paperwork.

---

## 5. Step catalog

Common contract for every step skill: read `STATE.md` + `config.yml` → resolve knobs → build a
**self-contained dispatch prompt** (feature folder path, mode, question budget, role skill-pack,
exact artifacts to read — the agent never hunts) → dispatch → loop per `loops.*` mode → pause
for your review (unless `--auto`) → relay the agent's `Result/Summary/Next` → done.

| Step skill | Agent(s) | Reads | Writes | Loop | Notes |
|---|---|---|---|---|---|
| `specify` | specificator | request, codebase (light), PRODUCT/TECH | SPEC.md | — | question budget from config |
| `architect` | architect (→ researcher) | SPEC, codebase, TECH | ARCH.md | — | mode: scout (default in maintain) / design |
| `plan` | planner ⇄ verifier(plan) | SPEC, ARCH, codebase | PLAN.md | `loops.plan_check` | auto: fix up to max_iters, stall-stop; manual (default): one pass, fix-when-certain, rest → findings/open questions |
| `code` | coder | PLAN (self-contained) | code, commits, PLAN deviations | — | one task = one commit |
| `qa` | qa | SPEC ACs, diff, tests | tests, commits | — | can be disabled per config |
| `verify` | verifier (code) | SPEC, PLAN, codebase | PLAN `## Verification` | — | adversarial, AC-by-AC |
| `review` | reviewer | SPEC, diff | review notes → fixes via coder | `loops.review_fix` | stage 1 spec-compliance, stage 2 quality; manual/auto like `plan_check` |
| `reconcile` | — (inline) | SPEC, ARCH, git diff | SPEC/ARCH updated to reality; hands off to `curate` | — | no longer emits suggestions or archives (moved to curator) |
| `curate` | curator | git diff, SPEC/ARCH, existing skillset, ledger | skills / per-dir CLAUDE.md / `.claude/rules/` / root CLAUDE.md / DECISIONS.md; `knowledge-ledger.md`; `CURATE.md`; archives folder | — | owns durable knowledge; structural = refresh-from-source, convention = evidence threshold; `apply: review\|auto` |

---

## 6. Agent roster

All twelve are defined from day one — thin, one job each, boundaries locked before habits form.
Dormant agents (no workflow yet) are marked ◌.

| Agent | One job | Key inputs → outputs | Fixed params |
|---|---|---|---|
| specificator | find the gray areas, ask the right questions, write the spec | request → SPEC.md | `questions: none\|few\|regular\|many` |
| architect | pick patterns/mechanisms; design only what's new | SPEC → ARCH.md | `mode: scout\|design` |
| researcher | deep online research; return a distilled brief | question → ≤2k-token brief (+ optional RESEARCH.md) | `depth: quick\|deep` |
| planner | turn SPEC+ARCH into grounded atomic-commit tasks | SPEC, ARCH, code → PLAN.md | — |
| coder | implement the plan, task by task | PLAN → commits + deviation log | `tasks: all\|T<n>..` |
| qa | tests that prove the ACs | SPEC, diff → test commits | — |
| verifier | find discrepancies between promise and reality | SPEC+PLAN (+code) → verdicts | `mode: plan\|code` |
| reviewer | two-stage review: compliance, then quality | SPEC, diff → findings | `stage: spec\|quality\|both`, `lite` |
| curator | keep the project's durable knowledge true to the code | diff, SPEC/ARCH, skillset, ledger → skills/CLAUDE.md/rules/DECISIONS edits + ledger | `apply: review\|auto` |
| ◌ brainstormer | go wide: options, trade-offs, best practices | idea → options brief | — |
| ◌ debugger | hypothesis-driven debugging | symptom → root cause | `lite` |
| ◌ extender | improve minions itself; knows §10 conventions + feedback.md | feedback → skill/agent edits | — |

**Context-isolation rule** (why researcher exists): any agent whose raw inputs are bulky and
disposable (web pages, long logs, big file sweeps) must be its own agent so the caller receives
only the distilled brief. The architect never sees a web page.

**Return convention** (every agent, last thing in its reply — the no-schema schema):

```
Result: ok | blocked | needs-input
Wrote: <files touched / commits made>
Summary: <≤10 lines, plain language>
Deviations/Warnings: <or "none">
Next: <suggested next step>
```

---

## 7. Artifacts

```
docs/minions/                     ← root configurable; gitignore-able on work repos
  config.yml                      §8
  STATE.md                        where are we — tiny digest, never an archive
  PRODUCT.md                      what/why for humans-who-forgot (rich in vibe mode,
                                  near-static in maintain mode)
  TECH.md                         thin index + pointers: layers, and where each area's
                                  conventions live (per-dir CLAUDE.md / .claude/rules/) — the
                                  content lives on native surfaces, not here (§11.19)
  DECISIONS.md                    append-only: date | decision | why
  feedback.md                     framework gripes, captured in the moment
  knowledge-ledger.md             curator's cross-feature evidence: candidate conventions +
                                  observation counts; survives archive (§13 resolved)
  features/
    012-export-rate-limit/
      SPEC.md                     goal · AC-1..AC-n (WHEN…SHALL…) · clarifications · out-of-scope
      ARCH.md                     patterns to follow (paths) · new elements · libraries
      PLAN.md                     tasks (do/check/commit/covers) · warnings · deviations ·
                                  verification — the feature's single running record
      CURATE.md                   curator's run summary: promotions, refreshes, flags, ledger
                                  deltas (written last; the per-feature record of what changed)
    archive/
      012-export-rate-limit/     moved here by curate
```

**Caps:** SPEC ≤150 lines, ARCH ≤150, PLAN ≤400, STATE ≤40, TECH ≤150; PRODUCT uncapped. These
are **soft targets, not hard stops** — going over is a *smell* (the content may belong on a
native surface per §11.19, or not at all), not a wall the agent hits mid-task. Their job is to
fend off the markdown sea (§11, failure mode 1) without strangling a genuinely complex feature.

**ID scope:** `AC-n` and `T-n` are meaningful only inside their feature folder. Nothing outside
the folder ever references them. This keeps Kiro-style traceability (task `covers: AC-2`,
verifier checks AC-2) while killing the GSD experience of meeting `CR-01` in a file far from
its definition.

**Knowledge placement:** durable repo knowledge does *not* live in `docs/minions/` — that tree
is minions-private (only dispatched agents read it, and only when ordered to). Conventions meant
to help *every* Claude session — including plain edits and teammates not running a workflow —
live on Claude Code's native progressive-disclosure surfaces: root `CLAUDE.md` (always on, kept
tiny — conventions that vary from defaults only), per-directory `CLAUDE.md` and `.claude/rules/`
path-scoped rules (load only when Claude touches matching files — this is where area specifics
like "controller conventions" go, scoped `**/controllers/**`), and skills (load on task match).
TECH.md is the *index* into those surfaces, not a second copy of them; ARCH.md is feature-scoped
and archived, never a home for durable knowledge. reconcile is the producer that *proposes*
writes to those surfaces — as tagged suggestions in `RECONCILE.md`, applied by you, never by the
step itself (§4 step 8, §11.19).

**Framework footprint & orientation pointer:** minions' footprint follows `mode` — *personal* in
maintain, *part of the project* in vibe. A fresh session (or the main orchestrator) learns minions
is even in play three ways, all **self-scoped to people who actually have the plugin**: the guard
hook (§9, plugin-level — it physically cannot reach a teammate without minions), `/minions:status`,
and a small **orientation pointer** — a fenced `<!-- minions -->` block naming what minions is,
where state lives (`docs/minions/`, read `STATE.md` first), and the command to orient.
`/minions:init` writes that block to the surface matching the project's audience: **vibe → root
`CLAUDE.md`** (shared, always-loaded — collaborators share the workflow); **maintain →
`CLAUDE.local.md`** (loaded last, gitignored — so a colleague without the plugin never reads a
false "this repo uses minions" claim and never spends always-on context budget on a tool they
can't run). This is the same rule that makes `docs/minions/` itself gitignore-able on work repos
(see Artifacts header). The block is curator-managed and, like every root `CLAUDE.md` edit,
human-gated (§4 step 9). Because `mode` tracks a rulebook, not headcount (§8), init states which
surface it chose and offers to flip it (a solo maintain repo may want the shared file; a
team-shared vibe repo may not).

**Writing style:** artifacts are written for a reader who does *not* know every class name
(vibe mode) or who knows the codebase well (maintain mode) — the specificator and planner adapt
prose to `mode`. Plans are self-contained (BMAD's lesson, §11.14): the coder reads PLAN.md and
nothing else.

**Root override:** default needs zero setup. To relocate or disable, a one-line `.minions-root`
file at repo root (`path: tools/minions` or `disabled`). Hooks and skills check it first.

---

## 8. Config

`docs/minions/config.yml`, created by `/minions:init`, read by every step skill and hook.
~10 keys, not 100 (GSD's config has 100+; nobody can hold that).

```yaml
mode: maintain            # maintain | vibe — does this project already have established, documented
                          # conventions you comply with (maintain), or are you still establishing
                          # them (vibe)? Drives knowledge behavior, architect default, prose, docs.
auto: off                 # off (default) = HITL: pause after every step, relay the result,
                          # suggest the next step. on = run steps back-to-back. Per-run: --auto
questions: regular        # none | few | regular | many — specificator interview budget
guard: soft               # off | soft | hard — see §9
loops:                    # each: manual (default) | auto | off
  plan_check: manual      # manual = one checked pass per run; auto = step loops up to max_iters
  review_fix: manual      # manual = fix-when-certain + document the rest; you re-run for more
  max_iters: 3            # iteration cap when a loop is auto; stall detection ends early
qa: on                    # on | off — separate QA pass after code
skills:                   # role → skills the dispatch prompt orders the agent to consult
  coder: [java-stack:java-style, java-stack:java-testing]
  reviewer: [java-stack:java-review]
  architect: []
docs:
  product: once           # once | living — vibe mode wants living
  tech: living
  knowledge: on           # on | off — master switch for the curator (see curate: below). off =
                          # no durable-knowledge updates at all (throwaway prototype).
curate:                   # the knowledge curator (2026-06-18-knowledge-curator-design.md)
  apply: review           # review (HITL default, pause for approval) | auto (commit directly;
                          # root CLAUDE.md still gated even under auto)
  promote_threshold: 3    # a convention must recur in N features before it becomes a written rule
  path: .claude/skills    # native surface for project skills
  cap_lines: 150          # soft cap per skill
  skills:
    structural: [tech-stack, architecture]                       # refreshed from source each feature
    convention: [code-style, design-patterns, testing, logging]  # evidence → threshold → rule
```

Per-invocation flags override config: `/minions:feature "..." --questions=few --auto`.
`--auto` runs the whole workflow hands-off; scope it to one loop with `--review=auto` /
`--plan-check=auto`. Skills declare fixed parameters via the `arguments:` frontmatter field so
they behave like parametrized scripts (must-have #11).

**HITL by default.** Workflows are human-in-the-loop. After each step the workflow skill relays
the agent's `Result/Summary/Next`, surfaces the artifact (brief, plan, diff), and **stops** —
you review it and tell it to proceed; the workflow already knows the next step and which
skill/agent runs it. `--auto` (or `auto: on`) removes the pauses for a hands-off run. This is
why there is no `gates:` list: pausing isn't a per-step setting to curate, it's the default, and
`--auto` is the single escape hatch (§11.15).

**Manual vs auto loops.** A loop in `manual` mode (default) does **one pass per invocation**:
the reviewer/verifier fixes only what it is *certain* about and documents the rest as findings
and open questions in PLAN.md — then stops. You read them and re-run the step, often in a fresh
session, for the next iteration. `auto` hands the loop to the step skill, which re-dispatches
fixes up to `loops.max_iters` with stall detection (§11.13). Manual keeps you between
iterations; auto trades that for momentum.

**Skill packs** are the Agent OS conditional-injection idea (§11.17): the step skill copies the
role's list into the dispatch prompt as *"before working, invoke these skills and obey them"*.
Per-project, explicit, no autodetection magic.

**Modes.** `mode` is the framework's main axis, and it is *not* about a project's age — it's about
whether established, documented conventions already exist. A brand-new microservice inside a work
monorepo with company skills and house patterns is `maintain`; a months-old solo side project with
no rulebook is `vibe`. Greenfield is just one case of `vibe`.

The two modes are mirror images on the **knowledge** axis (this is why knowledge style is derived
from mode, not a separate key):

- **maintain → comply.** Conventions live elsewhere already (company skills, existing patterns,
  prior docs). Agents *conform* to them; the architect defaults to **scout** (find and follow the
  existing pattern); reconcile mostly verifies compliance and only *suggests* where it spots an
  **undocumented** pattern or a needed edit. `docs.product: once`, `docs.tech: living` but thin.
- **vibe → establish.** No rulebook exists yet, so the framework actively *builds* one: reconcile
  proposes styling guides, dev patterns, arch choices, and abstractions onto the native surfaces
  (§11.19) so feature #7 follows feature #3 instead of reinventing it; the architect leans
  **design**; prose explains more (you don't know every class name). `docs.product: living`.

Both still route durable knowledge to the native surfaces and still require human approval to
apply it (§11.19) — `vibe` just *generates* more of it and `maintain` *defers* to what's there.
`docs.knowledge: off` silences recording in either mode (e.g. a throwaway prototype).

---

## 9. Enforcement: two hooks, no more (v1)

Plugin-level `hooks/hooks.json` (plugin agents can't carry hooks — platform restriction).

1. **Guard** — `PreToolUse` on `Edit|Write`. Script: is there an active minions workflow
   (STATE.md) covering this work? Is the file source code (not docs/scratch)?
   - `soft` (default): inject `additionalContext` — *"No active minions workflow. For
     code changes use /minions:quick or /minions:feature."* Claude steers; you can ignore it.
   - `hard`: `permissionDecision: deny` with the same message. Escape hatch: `guard: off`.
   - `off`: hook exits silently.
2. **Reconcile reminder** — `Stop` hook: if a feature is mid-flight past `code` and reconcile
   hasn't run, append a one-line reminder. Never blocks.

Both hooks are plugin-level, so they only ever fire for someone who has minions installed — a
teammate without the plugin gets nothing injected. That self-scoping is why the guard doubles as
the safest orientation surface in a shared (maintain) repo: it reaches *you* and never confuses
*them* (§7, framework footprint).

Start soft everywhere; escalate per-project only where drift actually bites (principle 8).
GSD ships 11 hooks; the lesson of its weight is that each hook must pay rent.

---

## 10. Framework conventions (how minions itself is written)

- **Skill descriptions are triggers, not summaries** — "Use when…" + symptoms. A description
  that summarizes the workflow gets *followed instead of the skill body* (superpowers' CSO
  failure, §11.12). Front-load the key trigger: listings truncate.
- **SKILL.md < 500 lines** (Anthropic guidance); detail goes to `references/` files loaded on
  demand — progressive disclosure is metadata → body → references.
- **Hard gates as tags** (`<HARD-GATE>`), red-flag/rationalization tables for discipline rules
  (superpowers patterns) — but only where an agent under pressure would rationalize; not on
  every skill.
- **Announce pattern:** skills state "Running minions <step> — <purpose>" so usage is auditable.
- **Agents:** one job in the first sentence; numbered "When invoked:" flow; explicit output
  format (the §6 return convention); minimal tool list.
- **$0 is the first skill argument** (2026 change); named args via `arguments:`.
- **Evals:** each skill may carry `evals/` (the existing `explainer` convention).
  `feedback.md` entries graduate into eval cases. Discipline rules get the superpowers
  writing-skills treatment: run the pressure scenario *without* the rule (RED), add the rule,
  re-run (GREEN), close loopholes.

---

## 11. Idea provenance — what we took, from where, and why it works

### 11.1 Thin orchestrators + fresh-context workers — *from GSD & Anthropic*
**There:** GSD workflows are coordinators that spawn 33 agent types, each with a fresh 200k
window; Anthropic's context-engineering guidance: workers "explore extensively but return only
a condensed, distilled summary (1,000–2,000 tokens)."
**Why it works:** quality degrades as a context window fills ("context rot"); isolating bulky
reading/reasoning in disposable windows keeps every actor at peak quality and the orchestrator
cheap.
**Here:** the entire 3-layer architecture (§3); the researcher agent existing at all.

### 11.2 State as human-readable files; STATE.md as the handoff — *from GSD (and minions v1)*
**There:** GSD's `.planning/STATE.md` carries position, decisions, learnings; survives `/clear`,
crashes, compaction.
**Why it works:** chat context is volatile and expensive; disk is neither. A file the human can
also read doubles as the audit trail.
**Here:** read-first/write-last protocol; resumability of any workflow mid-step from a cold
session.

### 11.3 The clarify interview — *from GitHub spec-kit `/clarify`*
**There:** scans the spec against a 9-category ambiguity taxonomy (scope, data, UX,
non-functional, integrations, edge cases, constraints, terminology, completion signals), asks
**max 5 questions, one at a time, multiple-choice with a recommended option**, and after each
answer immediately edits the spec **in place** plus logs `Q→A` in a dated Clarifications
section.
**Why it works:** bounded question count respects the human; multiple-choice with a
recommendation is answerable in seconds; in-place edits mean the spec is always current — the
interview *is* the editing.
**Here:** the specificator's entire method, with the question budget made configurable
(`none/few/regular/many`) because question tolerance is personal and per-project.

### 11.4 EARS acceptance criteria + task back-references — *from AWS Kiro*
**There:** requirements.md holds user stories with EARS-notation criteria ("WHEN X, THE SYSTEM
SHALL Y"); tasks carry `_Requirements: 1.1, 2.3_` back-refs. The single most-praised element of
Kiro.
**Why it works:** testable phrasing turns "done" from a vibe into a checklist; back-refs give
the verifier something mechanical to verify and make scope creep visible (a task covering no AC
is a smell).
**Here:** SPEC.md's `AC-n` list; PLAN tasks' `covers:` field; verifier's AC-by-AC verdicts.
Adapted per the lean-framework consensus: IDs scoped to one feature folder, no global registry
— this specifically fixes the GSD "what is CR-01?" navigation pain.

### 11.5 Goal-backward, adversarial verification — *from GSD's verifier*
**There:** "Do NOT trust SUMMARY.md claims." Derive from the goal: what must be TRUE → what
must EXIST → what must be WIRED; check each level against the actual codebase with stub-detection
greps (`TODO`, `return null`, log-only functions); classify VERIFIED / FAILED / UNCERTAIN.
**Why it works:** task completion ≠ goal achievement — a file can exist, compile, and still be a
stub. An agent told to be adversarial, with named "how verifiers go soft" failure modes, finds
what a friendly check misses.
**Here:** verifier agent verbatim in spirit, in both modes (plan mode: does the plan cover the
ACs and reference real code; code mode: do the ACs hold in reality). We drop GSD's override
system — verification debt is a lie with paperwork; criticals get fixed.

### 11.6 Deviation rules: auto-fix and always log — *from GSD's executor*
**There:** Rule 1 auto-fix bugs, Rule 2 auto-add missing critical functionality, Rule 3
auto-fix blocking issues; excluded: package installs (slopsquatting risk → human checkpoint);
every deviation tracked in the summary.
**Why it works:** reality always deviates from plan; stopping for every discovery kills flow,
but silent deviation rots the spec. Fix-and-log preserves both momentum and truth, and feeds
reconcile/verify exactly what changed.
**Here:** coder's deviation protocol, logged into PLAN.md `## Deviations`, consumed by verify
and reconcile (must-have #2: retrospective plan truth).

### 11.7 Atomic commit per task, check included — *from GSD + superpowers*
**There:** GSD: one task = one commit, `files_modified` ownership; superpowers: every plan step
is 2–5 minutes with exact commands and expected output, commit as its own step.
**Why it works:** git history becomes the progress tracker (resume = `git log` vs plan),
review-sized diffs, per-task revert; the bundled check makes each commit *trustworthy*, not
just small.
**Here:** PLAN task anatomy (do / check / commit / covers) and the coder's execution contract.

### 11.8 Two-stage review: compliance then quality — *from superpowers subagent-driven-development*
**There:** after each task, a spec-compliance reviewer (built exactly what was asked — including
catching *extra* unrequested work) must pass before a code-quality reviewer runs.
**Why it works:** a single "review this" pass anchors on style and misses scope drift; splitting
the question forces both answers. The YAGNI catch (built too much) is something no single-stage
review reliably produces.
**Here:** reviewer agent's two stages; stage one compares diff against SPEC ACs + out-of-scope
list.

### 11.9 Reconcile / living truth — *from OpenSpec (+ community practice; minions v1 instinct)*
**There:** OpenSpec change folders are ephemeral; on archive, **delta specs merge into a
permanent `specs/` describing what the system does now**. Community: spec changes ride the same
PR; periodic snapshot passes rewrite stale specs. The genre's verdict: frameworks without a
reconcile step accumulate lies that poison future LLM context.
**Why it works:** it makes the *change* documentation disposable and the *system* documentation
durable — matching how knowledge actually ages.
**Here:** the reconcile step (§4 step 8) updates SPEC/ARCH to the real diff; the **curate** step
(§4 step 9, curator agent) then folds durable learnings onto the native surfaces / DECISIONS.md and
archives. Full delta-merge into a `specs/` tree is a candidate later extension once the native
surfaces outgrow a flat layout.

### 11.10 Tiered workflows with upgrade signals — *gap in the field; nearest priors: Kiro, Taskmaster*
**There:** Kiro's only right-sizing is a binary vibe-vs-spec mode (its existence is an
admission); Taskmaster scores task complexity 1–10 to decide expansion; Fowler/Böckeler name
right-sizing as spec-driven development's unresolved question. A bug fix becoming 4 user
stories with 16 acceptance criteria is the canonical horror story.
**Why tiers work:** ceremony disproportionate to the task is the #1 reason users abandon
frameworks entirely — and an abandoned framework enforces nothing. Graduated tiers keep small
work *inside* the system.
**Here:** quick/feature/project tiers (§4) with bidirectional scope signals — the framework's
main original contribution.

### 11.11 Steering docs, small and earned — *from Kiro steering / Agent OS / spec-kit constitution*
**There:** Kiro's `product.md`/`tech.md`/`structure.md` auto-loaded each interaction; Agent OS
v3 *conditionally injects* only relevant standards; spec-kit's constitution holds the
non-negotiables. 2026 consensus: keep them short — bloated rule files get *uniformly
down-weighted*, and every line should trace to a real incident ("if you can't point to the
incident, the rule is paying tax").
**Why it works:** persistent context files are the cheapest way to make every session
project-aware — but only while they stay small enough to be obeyed.
**Here:** PRODUCT.md + TECH.md + DECISIONS.md with caps; `docs.product: once` in maintain mode
(your endpoint doesn't change the product story); reconcile proposes additions only when the
diff proves a new convention.

### 11.12 Skill-writing discipline — *from superpowers + Anthropic*
**There:** superpowers' CSO finding: if a description summarizes the workflow, Claude follows
the description and skips the body (documented: a "code review between tasks" description
caused one review where the skill required two). Hard gates as tags, red-flag tables countering
specific rationalizations. Anthropic: <500-line SKILL.md, three-level progressive disclosure,
descriptions as trigger conditions.
**Why it works:** skills are prompts under adversarial conditions (pressure, long context,
truncation); these patterns are tested countermeasures, not style preferences.
**Here:** §10 wholesale.

### 11.13 Bounded loops with stall detection — *from GSD's plan-checker*
**There:** planner → checker → revise, max 3 iterations; if the issue count stops decreasing,
escalate early instead of burning the remaining budget.
**Why it works:** one round of independent checking catches real gaps cheaply; unbounded loops
churn; the cap + stall rule converts "iterate until good" into a terminating algorithm.
**Here:** `loops.plan_check` and `loops.review_fix` (§8) default to `manual` — one checked pass,
then you decide — because the HITL default (§8) already puts a reviewer (you) between iterations.
`auto` runs up to `loops.max_iters` (default 3, GSD's habitual count) with stall-stop for
hands-off runs. Criticals block; warnings and open questions are recorded and move on.

### 11.14 Self-contained work units — *from BMAD story files*
**There:** the Scrum Master compiles each story with *all* the architecture/PRD context the dev
agent needs, so the dev reads one document. (The rest of BMAD — 7 personas, 31k tokens/run —
is the cautionary tale.)
**Why it works:** an executing agent that must hunt across documents burns context on
navigation and misses things; embedding the needed context moves that cost to planning time,
where it's paid once.
**Here:** PLAN.md is written to be executed alone; step skills build self-contained dispatch
prompts (§5).

### 11.15 Lean per-project config; HITL by default, one `--auto` escape — *from GSD's config.json + interactive-vs-yolo, inverted*
**There:** 100+ keys, an interactive-vs-yolo switch, per-step gate lists, model profiles,
per-agent overrides — powerful and unholdable.
**Why it works:** trust differs per project *and* per task; the same human wants hands-off on a
toy and a checkpoint at every step at work.
**Here:** §8 — kept the insight, dropped the per-step `gates:` list (curating which steps pause
is itself the ceremony this framework avoids). Workflows are **human-in-the-loop by default** —
every step pauses, relays, and suggests the next — with a single `--auto` flag (whole-workflow,
or scoped to a loop) as the one escape hatch. Config stays ~10 keys.

### 11.16 Steering hooks over blocking hooks — *Claude Code 2026 platform patterns*
**There:** hooks now support `additionalContext` injection (docs: "factual, not imperative"),
`prompt`/`agent` handler types (model judgment instead of regex), and `permissionDecision:
deny` for hard stops. GSD ships 11 hooks; superpowers ships 1.
**Why soft-first works:** a guard that fights the developer daily gets disabled, and a disabled
guard enforces nothing (same logic as tiers). Context injection recruits the model as the
enforcement layer; denial stays available where a project earns it.
**Here:** §9 — two hooks, `soft` default, `hard` per config.

### 11.17 Role-scoped skill packs — *from Agent OS conditional standards injection*
**There:** Agent OS v3 auto-discovers coding standards and injects only those relevant to the
task at hand, instead of loading everything always.
**Why it works:** always-loaded mega-guidelines dilute instruction weight until critical rules
sink with the noise; loading per-role keeps each agent's context sharp.
**Here:** `skills:` config map (§8) — explicit rather than auto-discovered, because at work the
mandatory list (java-stack pack) is known and non-negotiable.

### 11.18 Evals + feedback loop for the framework itself — *from superpowers writing-skills + skill-creator*
**There:** writing-skills applies TDD to documentation: run a pressure scenario *without* the
skill and record the rationalizations verbatim (RED), write the skill against them (GREEN),
re-test and close loopholes (REFACTOR). The existing `explainer` skill's `evals/` shows the
local convention.
**Why it works:** skills regress invisibly when edited; an eval corpus built from *actual
observed failures* (not imagined ones) is the only way edits make agents better, not worse.
**Here:** `/minions:feedback` captures friction the moment it occurs; the extender agent later
turns `feedback.md` into eval cases and skill edits (roadmap step 6).

### 11.19 Native progressive-disclosure surfaces as the knowledge store — *from Claude Code 2026 large-codebase guidance*
**There:** Anthropic's large-codebase guide prescribes a four-surface split: root CLAUDE.md
(always loaded — keep it to conventions that vary from defaults, <300 lines; HumanLayer runs
<60), per-directory CLAUDE.md (loads on demand when Claude reads files in that dir),
path-scoped rules in `.claude/rules/` with a `paths:` glob (load when a matching file is
touched), and skills (load on task match). Field consensus (HumanLayer, sshh.io): **pointers,
not copies** — never `@`-embed a large doc into CLAUDE.md, because it then costs context every
turn; name the path and pitch *when* it matters instead.
**Why it works:** always-loaded instruction budget is scarce (~20k-token baseline before the
first prompt) and bloated rule files get uniformly down-weighted (§11.11). On-demand surfaces
keep each session's context sharp while still making the whole repo's knowledge reachable — the
per-directory and path-scoped surfaces answer "controller specifics" without a single file that
bloats.
**Here:** the **curator** agent (§6, the `curate` step §4 step 9) classifies each durable learning
by *trigger type* — what loads it at the right moment: a *task/intent* → a skill (the dominant
surface), *touching a directory* → per-dir `CLAUDE.md`, *touching a glob* → `.claude/rules/` +
`paths:`, *every turn* → root `CLAUDE.md`, the *why* → DECISIONS.md. It then writes the edits
(structural facts refreshed from source, conventions promoted past a threshold) under
`apply: review|auto`, with root `CLAUDE.md` always human-gated — so the always-loaded surfaces never
change as a silent side effect. This is the non-minions-specific carrier for repo knowledge — a
teammate doing a plain edit benefits without ever running a workflow. TECH.md stays a thin index
(§7); ARCH.md remains feature-scoped and archived. Distinct from §11.17: role-scoped skill *packs*
are minions' dispatch-time injection; this is about where repo truth *persists* between sessions.
Full mechanism: `2026-06-18-knowledge-curator-design.md`.

### Explicitly rejected (and from whom)
- **Global requirement/decision ID registries** (GSD `REQ-001`/`D-01`, spec-kit FR-numbers):
  ceremony that created the navigation pain this framework exists to escape.
- **Persona theater / manager agents** (BMAD): roles without enforcement value; ~31k
  tokens/run and a 2-month learning curve for output a step list achieves.
- **Verification overrides / debt** (GSD): institutionalized lying about coverage.
- **8-mode workflow dispatchers, 67-command surfaces, namespace routers** (GSD): complexity
  that exists to manage complexity.
- **Spec-as-source regeneration** (Tessl): non-deterministic; not practical yet.
- **Strict tech-free/tech-full document separation** (spec-kit): artificial for a solo
  developer; ARCH.md is allowed to name classes.

---

## 12. Build roadmap

**Step 5 — the basics (each increment used on a real task before the next):**

1. **Skeleton:** `/minions:init` (creates `docs/minions/`, config.yml via short interview,
   templates, and the mode-conditional orientation pointer §7), `/minions:status`,
   `/minions:feedback`, STATE.md conventions, all templates.
2. **The spine:** `/minions:feature` + step skills `specify`/`plan`/`code`/`verify` + agents
   specificator, planner, coder, verifier (+ all 11 agent files created, dormant ones thin).
3. **Close the loop:** `architect` + `qa` + `review` steps wired; reconcile inline; **`curate`
   step + `curator` agent** (knowledge layer, `apply: review` default, threshold 3); plan-check
   loop wired (manual default).
4. **Guard:** the two hooks (§9), soft mode.
5. **`/minions:quick`.**

**Step 6 — extensions, bit by bit (order negotiable, driven by feedback.md):**
`/minions:project` (brainstormer goes live) → `/minions:debug` (debugger) → `/minions:research`
(researcher solo flow) → `/minions:inspect` → reviewer sub-specialists if the single reviewer
proves shallow → evals harness via skill-creator → extender agent → `/minions:refactor` →
(candidate) OpenSpec-style delta-merge if TECH.md outgrows itself.

---

## 13. Open questions (parked, not blocking)

- Does `qa` stay a separate post-code step, or does real usage show it belongs inside `code`
  (TDD-style, tests first)? Decide after ~5 features.
- Model assignments per agent (e.g. haiku for status/feedback paths) — defer until cost hurts.
- `project` workflow's scoping front-end: how much of spec-kit's constitution idea to adopt for
  greenfield. Design when we get there.
- Whether `quick` should auto-detect "you're editing an archived feature" and offer to reopen
  its folder.
- Should `--auto` also lower the interaction budget (e.g. imply `questions=few`), or stay
  orthogonal to `questions`/`guard`? Currently orthogonal.
- ~~Where do unapplied `RECONCILE.md` suggestions go after archive?~~ **Resolved** by the curator's
  `knowledge-ledger.md` (survives archive, tracks candidate conventions + observation counts) — see
  `2026-06-18-knowledge-curator-design.md` §5.
