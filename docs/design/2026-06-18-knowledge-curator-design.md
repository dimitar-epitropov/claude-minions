# minions v2 — The Curator: living project knowledge

**Date:** 2026-06-18 · **Status:** approved design, pre-implementation
**Extends:** `2026-06-12-minions-v2-design.md` (§4 step 8 reconcile, §6 agent roster, §8 config,
§11.19 native surfaces, §13 open questions). Read that first — this doc only adds the curator.

The curator is the engine that makes minions' knowledge layer *live*: every feature iteration it
brings the project's durable documentation — skills, `CLAUDE.md` files, path-scoped rules,
decisions — back into agreement with the code that just shipped. It is the missing producer behind
§11.19: that section says *where* durable knowledge belongs; the curator is *who puts it there and
keeps it true*.

---

## 1. Why this exists

The v2 design routes durable knowledge to Claude Code's native progressive-disclosure surfaces
(§11.19) and has `reconcile` *suggest* edits a human later applies by hand. Two gaps:

1. **No engine.** "A human applies the suggestions" is where living documentation goes to die — it
   is the exact manual-discipline failure mode every prior tool hits (Cline's `update memory bank`
   phrase, Cursor's re-run, AGENTS.md's "treat it as living documentation"). The knowledge that
   makes feature #7 follow feature #3 only accrues if *something* reliably writes it down.
2. **No memory between features.** A durable convention usually isn't provable from one diff. With
   reconcile emitting one-shot suggestions and the feature folder then archived, evidence for a
   convention that recurs across features is lost each cycle.

The curator closes both: a read-heavy librarian agent, run once per feature, that owns the entire
durable-knowledge layer and carries a persistent ledger across features.

**Research provenance** (the mechanisms this steals, see the three briefs that informed it):

- **Type-split: factual vs convention** — *Aider repo-map.* Auto-derived structural facts can't
  drift, so regenerate them from source; reserve the careful path for intent/conventions.
- **Evidence threshold before a rule** — *NATURALIZE (FSE'14), ExpeL (AAAI'24).* A pattern becomes
  a rule only past a support count; one observation is noise. A study found LLM-*generated*
  convention files hurt in 5/8 settings — auto-summarizing one diff restates noise.
- **Detection deterministic, mutation by agent** — *`drift`.* Find candidate-stale lines
  mechanically; let the agent rewrite.
- **ADD/UPDATE/NOOP gate + dedup-before-write** — *Mem0.* Stops the same fact being re-added.
- **Managed-block anchors** — *Ansible `blockinfile`.* Rewrite in place, never blind-append.
- **Verify-before-trust** — *Anthropic adversarial review.* Confirm a claim against live code
  before keeping it.
- **Prune test ("would removing this cause a mistake?")** — *Anthropic CLAUDE.md guidance.* The
  universal failure mode across every prior tool is bloat → instructions ignored.
- **Bounded, self-pruning insight set** — *ExpeL importance counters; Karpathy lint-agent.* Noise
  decays out; a periodic hygiene pass catches cross-document drift.

---

## 2. Placement and the new feature tail

A new agent **`curator`** (agent #12) and a new step skill **`curate`**. The step runs at the end
of every feature, **after `reconcile`, before archive**:

```
… → review → reconcile → curate → archive
```

- **`reconcile`** (unchanged in spirit, now *narrower*): folds SPEC.md and ARCH.md to the real
  `git diff` — those two are feature-local and about to be archived. It **no longer emits
  knowledge suggestions and no longer archives.** It hands the feature to `curate`.
- **`curate`** (curator agent): owns the durable-knowledge layer end to end — classify, route,
  refresh, promote, write, verify — then archives the feature folder last, so knowledge is captured
  *before* the folder disappears.

This is a structural simplification of v2: the knowledge-routing logic previously split between
reconcile (§4 step 8) and §11.19's "the human applies it" now lives in **one** agent with one
contract. `feature`, `project` (per backlog item — this is what grows the skillset across a
greenfield build), and `quick` (only behind `--curate`) all reuse the same step.

`curate` is independently invocable: `/minions:curate` re-runs curation for the active or
just-finished feature; `/minions:curate --init` bootstraps; `/minions:curate --audit` runs the
hygiene pass (§9, deferred).

---

## 3. What it owns: the whole durable-knowledge layer

The curator owns **every native surface** from §11.19, plus DECISIONS.md. For each durable learning
it makes two orthogonal decisions:

**(a) Which surface? — routed by *trigger type* (the §11.19 refinement):** ask *what loads this at
the right moment?*

| Learning triggers on… | Surface | Update class |
|---|---|---|
| a *task / intent* ("adding logging", "where does new code go"), often cross-directory | **skill** (`.claude/skills/<name>/`) | per (b) |
| *touching files in one directory* | per-directory `CLAUDE.md` | per (b) |
| *touching files matching a glob* (all controllers) | `.claude/rules/*` + `paths:` glob | per (b) |
| *every turn*, a cross-cutting non-negotiable | **root `CLAUDE.md`** (tiny, always-on) | factual, **always human-gated** (§6) |
| the *why* behind a choice | `DECISIONS.md` (append-only) | factual, append |

Skills are the dominant surface (task-triggered, cross-directory, independently testable); per-dir
`CLAUDE.md` and path-scoped rules are the narrower fallback for genuinely location-bound knowledge.

**(b) Factual or convention? — sets the update mechanic:**

- **Factual / structural** (tech stack, architecture, where-code-goes, the *why*): **regenerated
  from source** every feature. Auto-derived → can't drift → safe to refresh (and safe under
  `apply:auto`). The curator reads the actual code, never trusts prose memory.
- **Convention / judgment** (code style, design patterns, naming, test conventions): **accumulate
  then promote.** A diff is *evidence*. Each candidate convention gets a counter in the ledger (§5);
  it becomes a written rule only at `promote_threshold` (default 3) observations across features.
  Existing convention rules are checked against the diff for contradiction and flagged.

### The seed skillset (fixed, config-defined)

The curator guarantees a seed set of project skills exists; missing ones are generated (§7),
present ones are maintained. Seed taxonomy (from `config.curate.skills`, modeled on the
`agentic-sdlc-temporal/.claude/skills` exemplar):

- **Structural** (factual path): `tech-stack` (languages, frameworks, libs + versions, build/run/
  test commands — "all tech used"), `architecture` (layers, dependency direction, seams,
  where-code-goes).
- **Convention** (threshold path): `code-style`, `design-patterns`, `testing`, `logging`.

The curator may propose a skill *beyond* the seed when a recurring task-triggered pattern has no
home — gated like any new rule. Surfaces other than skills (per-dir `CLAUDE.md`, rules, root
`CLAUDE.md`, DECISIONS) are written reactively from routing, not from a fixed seed list.

### Authoring bar

Every skill the curator writes hits the §10 bar — and the `sdlc-*` exemplar is the reference: a
`Use when…` trigger description (not a summary), `Overview` → rules-as-tables → a `Red flags — stop`
list, and **pointers to DECISIONS.md / specs, not copies**. The curator's system prompt embeds
skill-creator's authoring rules so generated skills are triggers, not prose dumps. Root `CLAUDE.md`
edits obey its strict budget (conventions that vary from defaults only; HumanLayer runs <60 lines).

---

## 4. The two update paths, concretely

**Structural path (refresh from truth).** Read the diff to find which structural skills / per-dir
`CLAUDE.md` files the change touches; for each, re-derive the relevant facts from the current source
(targeted reads of changed areas + key structural files) and rewrite the affected managed block in
place. Verify each retained claim against live code before keeping it.

**Convention path (evidence → threshold → rule).** Mine candidate conventions from the diff (naming,
layout, abstraction choices, test shape). For each candidate: dedup against existing rules
(skip if already written); else increment its ledger counter and record the example `file:line`.
At `promote_threshold` observations, promote to a written rule on the routed surface. Separately,
test existing rules against the diff: a contradiction is **flagged** (not silently overwritten) for
human resolution.

---

## 5. The support ledger — and the answer to §13

`docs/minions/knowledge-ledger.md` — minions-private, **survives feature archival.** One row per
candidate convention:

```
candidate | first-seen feature | observations | example refs (file:line) | status
```

`status ∈ candidate | promoted | rejected`. ExpeL-style importance counter: observations accrue
across features; a candidate not re-seen for many features decays and is pruned; a promoted
candidate's row records where it landed.

This directly resolves **§13's parked question** ("where do unapplied suggestions go after
archive?"): they accrue here instead of dying in an archived folder. The ledger *is* the
`knowledge-inbox.md` that §13 floated — but structured as an evidence counter, which is also what
makes the threshold mechanic possible.

---

## 6. Convergence and anti-bloat (the part that matters over 50 features)

Every prior tool's universal failure is **bloat → instructions get down-weighted**. The curator's
defenses, all stolen and named:

- **Named managed-block anchors** per fact/rule → rewrite in place, never blind-append (`blockinfile`).
- **ADD / UPDATE / NOOP / FLAG** decision per candidate, behind a **dedup-before-write** similarity
  check (Mem0) — the same fact is never re-added; contradictions are FLAGGed, not overwritten.
- **Prune test** on every line it would add: *"would removing this cause Claude to make a mistake?
  If not, cut it."* Applied hardest to always-on root `CLAUDE.md`.
- **Soft caps**: ~150 lines/skill (the `sdlc-*` skills run ~50); root `CLAUDE.md` to its strict
  budget. Over-cap is a *smell* — content likely belongs on a more specific surface.
- **Verify-before-trust**: structural claims are grounded by reading the actual code, not memory.
- **Always-on surfaces are human-gated regardless of `apply` mode** (§6 below): root `CLAUDE.md` has
  the steepest bloat penalty, so it never changes as a silent side effect — even in `apply:auto`.

---

## 7. Apply model (config-switchable HITL)

`config.curate.apply`:

- **`review`** (default): the curator writes the real edits to a staged diff and a `CURATE.md`
  summary (promotions, refreshes, flags, ledger deltas), then **pauses for you to approve before
  commit** — the minions HITL default.
- **`auto`**: commits the edits directly (vibe-mode hands-off), recording the summary in `CURATE.md`
  + STATE. **Exception:** root `CLAUDE.md` edits still pause for approval even under `auto` — the
  one always-loaded surface is never touched unattended.

`docs.knowledge: off` disables the step entirely (throwaway prototype). The curator never commits
unattended unless `apply:auto` is explicitly set.

### Bootstrapping — "if we don't have them, generate them"

First run on a repo with no skillset (greenfield vibe, or adopting an existing project):
`/minions:curate --init` does a one-time fuller codebase scan to generate the seed skills (the
Cline `initialize memory bank` / Copilot `/init` move). Auto-fires on the first feature when no
skillset exists. Thereafter curation is incremental and diff-driven.

---

## 8. Mode behavior

- **vibe → establish.** Full curation; leans toward creating skills and writing conventions to
  build the rulebook; `apply:auto` is reasonable. This is the mode that makes feature #7 follow
  feature #3.
- **maintain → comply.** The curator mostly *verifies compliance* and refreshes structural facts;
  proposes a new convention skill only for a genuinely *undocumented* recurring pattern; defers to
  existing company skills and never duplicates them; `apply:review`.

---

## 9. Deferred (not v1)

A whole-skillset **librarian audit pass** (`/minions:curate --audit`, run every N features or
on demand): cross-skill contradictions, stale claims, orphan pointers, bloat — the Karpathy
lint-agent / Letta sleep-time-agent idea. Per-diff updates can't see cross-document drift; this
catches it. Build after the per-feature path proves itself.

---

## 10. Config additions (folds into v2 §8)

```yaml
docs:
  knowledge: on            # existing master switch — now also gates `curate`
curate:
  apply: review            # review (HITL default) | auto (commit directly; root CLAUDE.md still gated)
  promote_threshold: 3     # a convention must recur in N features before it becomes a rule
  path: .claude/skills     # native surface for project skills
  cap_lines: 150           # soft cap per skill
  skills:
    structural: [tech-stack, architecture]
    convention: [code-style, design-patterns, testing, logging]
```

---

## 11. Ripples back into the v2 doc (apply when this is accepted)

- **§4 step 8 (reconcile):** narrow it — SPEC/ARCH → reality, then hand off to `curate`; remove
  "emit tagged suggestions" and "archive" (both move to curate). Add `curate` as step 9.
- **§5 step catalog:** add a `curate` row (agent: curator; reads: diff, SPEC/ARCH, existing
  skillset, ledger; writes: skills/CLAUDE.md/rules/DECISIONS + ledger + CURATE.md; archives).
- **§6 agent roster:** add `curator` (#12) — "keep the project's durable knowledge true to the
  code"; promote it from the dormant set since `feature` now uses it.
- **§7 artifacts:** add `knowledge-ledger.md` (survives archive) and per-feature `CURATE.md`.
- **§8 config:** add the `curate:` block.
- **§11.19:** the routing table becomes trigger-type-based (§3a here); name the curator as its
  producer; skills become the dominant surface.
- **§12 roadmap:** curate + curator land in increment 3 ("close the loop") alongside reconcile.
- **§13:** mark the "where do unapplied suggestions go" question **resolved** by the ledger (§5).
```
