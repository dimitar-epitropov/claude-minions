# minions v2 — Increment 3c: reconcile (inline) + curate (curator agent)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the last two feature steps — **reconcile** (inline, folds SPEC/ARCH to the real diff)
and **curate** (the curator agent, the durable-knowledge librarian + archive) — so `/minions:feature`
runs the full spine `specify → architect → plan → code → verify → review → reconcile → curate` end to
end and the feature folder is archived at the close.

**Architecture:** Same three fixed layers (design §3). One **inline** step (`reconcile`, no agent —
the cheap exception design §4 step 8 allows) that edits SPEC.md + ARCH.md to match reality and hands
off. One **new agent created from scratch** — **curator** (agent #12, the knowledge librarian; there
is no dormant stub to flesh, unlike 3a/3b) — dispatched by a thin `curate` step. The curator owns the
entire durable-knowledge layer (skills / per-dir `CLAUDE.md` / `.claude/rules/` / root `CLAUDE.md` /
DECISIONS.md), carries a cross-feature `knowledge-ledger.md`, writes a per-feature `CURATE.md`, and the
`curate` **step owns commit + archive + terminal STATE** (the curator stages edits; the step finalizes
under the HITL `apply` model — mirroring how the 3b review step owns its terminal STATE). Full
mechanism: `docs/design/2026-06-18-knowledge-curator-design.md`.

**Tech Stack:** Markdown skills (`SKILL.md` + YAML frontmatter), agents (`agents/<name>.md` +
frontmatter), and artifact templates. No build, no runtime tests — "tests" are frontmatter/structural
greps plus a manual UAT run of the workflow in a throwaway project. Plugin loads from the
`depitropov-plugins` marketplace; each pushed commit is a new version.

## Decision recorded this increment: **QA is dropped for now**

Per the controller's call (2026-06-24): the **qa** step is **not** built in 3c and is **deferred
indefinitely** — not "next increment." `agents/qa.md` stays a dormant stub; no `skills/qa/`; the
`config.qa` key stays as a forward-declared no-op (nothing consumes it). The wired spine therefore
*skips* qa: `… → code → verify → …` (design §4's full sequence lists qa between code and verify; we
intentionally omit it). Task 5 records this in the master roadmap so the decision is durable, not just
buried in this plan. This also supersedes the 3b plan's framing of 3c as "reconcile + curate + curator"
— qa was already deferred there; it is now dropped, and 3c is exactly reconcile + curate.

## Supersession note (read before Task 1)

The **curator design doc (2026-06-18) is authoritative** over the older master design §4/§7 and the
master roadmap on these points:
- reconcile **no longer emits `RECONCILE.md`** and **no longer archives**. It only folds SPEC.md +
  ARCH.md to the real diff and hands off to curate. **Do not** create `templates/RECONCILE.md` (the
  master roadmap line ~470 calling for it is superseded).
- The curator emits **`CURATE.md`** (per-feature run summary) and maintains **`knowledge-ledger.md`**
  (cross-feature, survives archive), and it (via the step) **archives** the feature folder last.

## Global Constraints

The full set lives in `docs/plans/2026-06-19-minions-v2-build.md` (increment 2). Every task here
implicitly includes them. The ones that bite this increment:

- **Layer depth is exactly 3.** Workflow → step → agent. A step never invokes another step; a
  workflow never dispatches an agent directly; an agent never dispatches an agent — only step skills
  re-dispatch. **`reconcile` is the design-sanctioned inline exception** (§4 step 8): it does its own
  SPEC/ARCH edits, no agent. `curate` is a normal orchestrating step (dispatches the curator only).
  (§3)
- **Line caps (soft, smell-not-wall):** workflow skill ≤ ~50 lines, step skill ≤ ~80, agent body
  lean. New templates kept tiny. (§3, §7)
- **Skill descriptions are TRIGGERS, not summaries** — "Use when…", front-loaded, with a note the
  step is normally invoked by `/minions:feature` but runnable directly. (§10)
- **Agent return convention** — every agent ends with exactly: `Result: ok|blocked|needs-input` ·
  `Wrote:` · `Summary:` (≤10 lines) · `Deviations/Warnings:` · `Next:`. (§6)
- **State protocol** — every skill reads `<root>/STATE.md` first; resolve `<root>` from
  `.minions-root` (path/disabled) else `docs/minions/`. The **`reconcile` step writes its own
  terminal STATE** (it is inline, no agent). The **`curate` step owns its terminal STATE + archive**
  (its curator stages edits and writes no STATE, like the 3b reviewer). (§2, §7)
- **Self-contained dispatch** — the curate step hands the curator the feature path, mode, apply mode,
  the diff, SPEC/ARCH paths, the ledger path, and the seed-skill config. The curator never hunts. (§5,
  §11.14)
- **Mode is the main axis** — `maintain` = comply/verify, refresh structural facts, propose a new
  convention skill only for a genuinely undocumented recurring pattern, `apply: review`; `vibe` =
  establish, lean toward creating skills + writing conventions, `apply: auto` reasonable. (§8, curator
  design §8)
- **Knowledge anti-bloat is non-negotiable** — named managed-block anchors (rewrite in place, never
  blind-append), ADD/UPDATE/NOOP/FLAG + dedup-before-write, the prune test, verify-before-trust,
  evidence threshold (default 3) before a convention becomes a rule. Root `CLAUDE.md` is **always
  human-gated, even under `apply: auto`.** (curator design §3, §6, §7)
- **`docs.knowledge: off` disables curate entirely** (throwaway prototypes). (curator design §7)
- **Plugin agents can't carry `permissionMode`/`hooks`.** (§3)

---

## Increment 3c — reconcile + curate

New agent this increment: **curator** (created from scratch — agent #12, no dormant stub existed). New
steps: `reconcile` (inline), `curate`. New config block: `curate:` (added to the template — the master
design §8 already specifies it; the live template is missing it). New templates: `CURATE.md`,
`knowledge-ledger.md`. The `feature` workflow gains two steps; the wired spine becomes the full
`specify → architect → plan → code → verify → review → reconcile → curate` (qa intentionally omitted —
see the decision above). qa stays dormant.

### Task 1: config block + STATE enum + new templates + init wiring

**Files:**
- Modify: `templates/config.yml` (add the `curate:` block; document the `qa` key as a no-op for now)
- Modify: `templates/STATE.md` (add `curate` to the Step enum)
- Create: `templates/CURATE.md` (per-feature curator run summary)
- Create: `templates/knowledge-ledger.md` (cross-feature evidence ledger; survives archive)
- Modify: `skills/init/SKILL.md` (copy `knowledge-ledger.md` into the root at init; note curate defaults)

**Interfaces:**
- Produces: a `config.curate` block (`apply`, `promote_threshold`, `path`, `cap_lines`, `skills`)
  consumed by the curate step (Task 4) and curator (Task 2); a `CURATE.md` shape the curator fills
  (Task 2); a `knowledge-ledger.md` schema the curator appends rows to (Task 2); `<root>/knowledge-ledger.md`
  present after init.

- [ ] **Step 1: Add the `curate:` block to `templates/config.yml`**

Append after the existing `docs:` block (which ends with `knowledge: on`). Copy the master design §8
values verbatim:

```yaml
curate:                   # the knowledge curator (docs/design/2026-06-18-knowledge-curator-design.md).
                          # Gated by docs.knowledge above — knowledge: off disables curate entirely.
  apply: review           # review (HITL default — curator stages edits, you approve before commit)
                          # | auto (commit non-gated edits directly; root CLAUDE.md still gated)
  promote_threshold: 3    # a convention must recur in N features before it becomes a written rule
  path: .claude/skills    # native surface for project skills the curator writes
  cap_lines: 150          # soft cap per skill (the sdlc-* exemplar skills run ~50)
  skills:                 # the seed skillset the curator guarantees exists
    structural: [tech-stack, architecture]                       # refreshed from source each feature
    convention: [code-style, design-patterns, testing, logging]  # evidence -> threshold -> rule
```

Also update the existing `qa` key's comment to record the deferral (do **not** remove the key):

```yaml
qa: on                    # on | off — separate QA pass after code. NOTE: the qa step is not built
                          # yet (deferred); this key is a forward-declared no-op until then.
```

- [ ] **Step 2: Add `curate` to the STATE template Step enum**

In `templates/STATE.md`, the `**Step:**` line currently reads
`[none | specify | architect | plan | code | qa | verify | review | reconcile]`. Add `curate`:
`[none | specify | architect | plan | code | qa | verify | review | reconcile | curate]`.

- [ ] **Step 3: Create `templates/CURATE.md`**

The per-feature curator run summary (lives in the feature folder, archived with it). Keep it tiny —
it is a record, not an archive. Content:

```markdown
# CURATE — <NNN-slug>

> The curator's run summary for this feature: what durable knowledge changed, what is staged for
> your approval, and the ledger deltas. Written last, before the feature folder is archived.

**Updated:** <date> — curate run (<apply mode>)

## Promotions
- <convention promoted to a written rule this run — surface + threshold hit, or "none">

## Refreshes
- <structural facts re-derived from source this run — surface, or "none">

## Flags (need your resolution)
- <contradiction between an existing rule and the diff, or a root CLAUDE.md edit awaiting approval; "none">

## Staged edits (awaiting commit)
- <file -> one-line what-changed, for each edit written to the working tree but not yet committed; "none">

## Ledger deltas
- <candidate conventions added / incremented this run, with new observation counts; "none">
```

- [ ] **Step 4: Create `templates/knowledge-ledger.md`**

The cross-feature evidence ledger. Lives at `<root>/knowledge-ledger.md` (root, **not** feature-local —
it survives archive). Content:

```markdown
# minions knowledge ledger

> Cross-feature evidence for candidate conventions (curator design §5). Survives feature archival —
> this is where evidence accrues so a convention seen across features can cross the promote threshold.
> One row per candidate. status = candidate | promoted | rejected.
> ExpeL-style: observations accrue; a candidate not re-seen for many features decays and is pruned.

| candidate | first-seen feature | observations | example refs (file:line) | status |
|---|---|---|---|---|
| _none yet_ | | | | |
```

- [ ] **Step 5: Wire `knowledge-ledger.md` into init**

In `skills/init/SKILL.md`, find the `cp "$CLAUDE_PLUGIN_ROOT"/templates/...` block (the one copying
`config.yml`, `STATE.md`, etc.). Add a line copying the ledger into the root:

```bash
cp "$CLAUDE_PLUGIN_ROOT"/templates/knowledge-ledger.md <root>/knowledge-ledger.md
```

(Place it alongside the other root-file copies — `feedback.md` is a good neighbor; the ledger is a
near-empty root file like it.) `CURATE.md` is **not** copied at init — it is per-feature and the
curator writes it into the feature folder at curate time, following the template's shape.

- [ ] **Step 6: Validate**

```bash
grep -nE 'apply: review|promote_threshold|cap_lines|structural:|convention:' templates/config.yml   # curate block present
grep -q 'forward-declared no-op' templates/config.yml                                                # qa deferral noted
grep -q 'reconcile | curate' templates/STATE.md                                                       # curate in Step enum
test -f templates/CURATE.md && grep -qE 'Promotions|Refreshes|Flags|Staged edits|Ledger deltas' templates/CURATE.md
test -f templates/knowledge-ledger.md && grep -q 'first-seen feature' templates/knowledge-ledger.md
grep -q 'knowledge-ledger.md' skills/init/SKILL.md                                                    # init copies the ledger
! test -f templates/RECONCILE.md                                                                      # superseded — must NOT exist
```

- [ ] **Step 7: Commit**

```bash
git add templates/config.yml templates/STATE.md templates/CURATE.md templates/knowledge-ledger.md skills/init/SKILL.md
git commit -m "Add curate config block, CURATE.md + knowledge-ledger.md templates, init wiring"
git push origin main
```

### Task 2: curator agent (create from scratch — agent #12)

**Files:**
- Create: `agents/curator.md` (no dormant stub exists — create the file, frontmatter + body)

**Interfaces:**
- Consumes (from the curate step's dispatch prompt): feature folder path, `mode` (`maintain|vibe`),
  `apply` mode (`review|auto`), the feature's `git diff`, SPEC.md + ARCH.md paths, the
  `knowledge-ledger.md` path (abs), and the `config.curate` settings (`promote_threshold`, `path`,
  `cap_lines`, `skills.structural`, `skills.convention`).
- Produces: **edits written to the working tree (uncommitted)** on the native surfaces; an updated
  `knowledge-ledger.md`; a `<feature>/CURATE.md`. Writes **no STATE**, **does not commit**, **does not
  archive** — the curate step owns commit + archive + STATE (Task 4). Reports via the §6 return block.

Model the agent on `agents/verifier.md` (adversarial-but-mechanical shape: one-job sentence,
`## Hard gate`, numbered "When invoked", `## End of run` with the return block) and `agents/reviewer.md`
(reports inside a step's control). The curator's domain content comes from
`docs/design/2026-06-18-knowledge-curator-design.md` (read it).

- [ ] **Step 1: Write the frontmatter**

```yaml
---
name: curator
description: Use when a feature has shipped (reconciled) and the project's durable knowledge —
  skills, CLAUDE.md files, path-scoped rules, DECISIONS — must be brought back into agreement with the
  code that just landed. "Update the project knowledge", "refresh the skills/docs from the diff",
  "what conventions did this feature establish", or when /minions:feature reaches the curate step.
  Normally dispatched by the minions curate step, which hands you the feature, the diff, and the
  ledger; you classify each durable learning, route it to the surface that loads it at the right
  moment, refresh structural facts from source, promote recurring conventions past a threshold, and
  stage the edits. You keep knowledge TRUE to the code — you do NOT commit or archive.
tools: Read, Grep, Glob, Bash, Write, Edit
---
```

(The curator needs Write/Edit — it authors skills/CLAUDE.md/rules/DECISIONS. It needs Bash for
read-only git/grep and dedup checks. It does **not** commit — that is the step's job, enforced by the
hard gate, not by withholding tools.)

- [ ] **Step 2: Write the body**

Cover, in this order (lean prose — this is the heaviest agent, but stay focused; pointers to the design
doc, not copies):

1. **One job (first sentence):** keep the project's durable knowledge true to the code that just
   shipped — classify each durable learning, route it to the right native surface, refresh structural
   facts from source, accumulate conventions to a threshold, stage the edits. You **report and stage**;
   you do **not** commit and do **not** archive.

2. `## Hard gate` (`<HARD-GATE>`):
   - **Never commit, never archive.** Your writes go to the working tree, the ledger, and CURATE.md
     only. The curate step commits (per `apply`) and archives. (This is why you stage, not commit.)
   - **Root `CLAUDE.md` and the orientation pointer are ALWAYS human-gated** — write the proposed edit
     but FLAG it in CURATE.md; never treat it as auto-committable even when `apply: auto`.
   - **Evidence before a rule.** A single diff is *evidence*, not a rule. A convention becomes a
     written rule only at `promote_threshold` observations across features (via the ledger). One
     observation → increment the counter, do not write the rule.
   - **Verify before trust.** Ground every structural claim by reading the actual code, never prose
     memory. **Prune test** on every line you would add: "would removing this cause Claude to make a
     mistake? If not, cut it." Dedup before write — never re-add a fact already present.
   - **Never blind-append.** Rewrite inside named managed-block anchors in place.

3. **When invoked** — read the dispatch (feature folder, mode, apply, diff, SPEC/ARCH, ledger path,
   `config.curate`). Read the diff, SPEC.md, ARCH.md, the ledger, and the existing skillset at
   `config.curate.path`.

4. **For each durable learning, two orthogonal decisions** (curator design §3):
   - **(a) Which surface? — by trigger type:** task/intent (often cross-dir) → **skill**; touching one
     dir → per-dir `CLAUDE.md`; touching a glob → `.claude/rules/*` + `paths:`; every-turn
     non-negotiable → **root `CLAUDE.md`** (tiny, always-gated); the *why* → `DECISIONS.md` (append).
     Skills are the dominant surface.
   - **(b) Factual or convention? — sets the mechanic:**
     - **Factual / structural** (tech stack, architecture, where-code-goes, the why): **refresh from
       source.** Re-derive from the changed code + key structural files; rewrite the affected managed
       block in place. Safe under `apply: auto` (auto-derived can't drift).
     - **Convention / judgment** (style, patterns, naming, test shape): **evidence → threshold → rule.**
       Mine candidates from the diff; **dedup** against existing rules (skip if written); else increment
       the ledger counter + record an example `file:line`; **promote** to a written rule only at
       `promote_threshold`. Test existing rules against the diff — a contradiction is **FLAGGED**, not
       silently overwritten.

5. **The seed skillset** (`config.curate.skills`): guarantee the seed skills exist — structural
   (`tech-stack`, `architecture`) on the factual path, convention (`code-style`, `design-patterns`,
   `testing`, `logging`) on the threshold path. Generate a missing one; maintain a present one. Every
   skill you write hits the §10 authoring bar: a `Use when…` trigger description (not a summary),
   `Overview` → rules-as-tables → `Red flags — stop`, **pointers to DECISIONS/specs, not copies**;
   ≤ `cap_lines` (soft). You may propose a skill *beyond* the seed for a recurring task-triggered
   pattern with no home — gated like any new rule.

6. **Mode behavior:** `vibe` → establish: full curation, lean toward creating skills + writing
   conventions (this is what makes feature #7 follow feature #3). `maintain` → comply: mostly verify
   compliance + refresh structural facts; propose a new convention skill only for a genuinely
   undocumented recurring pattern; defer to existing company skills, never duplicate them.

7. **Apply staging (you stage, the step commits):**
   - Write all edits to the working tree (uncommitted).
   - Update `knowledge-ledger.md`: add/increment candidate rows (ExpeL counter), mark promotions.
   - Write `<feature>/CURATE.md` following `templates/CURATE.md` — fill Promotions, Refreshes, Flags,
     **Staged edits** (every file you touched), Ledger deltas. List root `CLAUDE.md`/orientation-pointer
     edits under **Flags** (always-gated) regardless of apply mode.

8. `## End of run` — do **NOT** write STATE, do **NOT** commit, do **NOT** archive. Return the §6 block
   last:
   ```
   Result: ok | blocked | needs-input
   Wrote: <feature>/CURATE.md, knowledge-ledger.md, + the staged surface edits (list them)
   Summary: <≤10 lines — promotions, refreshes, flags count, # staged edits, seed-skills status>
   Deviations/Warnings: <flags needing resolution (contradictions, root CLAUDE.md edits); "none" if clean>
   Next: /minions:curate
   ```
   `blocked` if the diff/SPEC/ARCH/ledger can't be read. `needs-input` if a contradiction needs the
   human before proceeding. `ok` once the pass is done (`ok` does not mean zero flags). `Next` points
   back at `/minions:curate` — the step finalizes (commit per `apply`, then archive).

- [ ] **Step 3: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/curator.md | grep -E '^(name|description|tools):'   # frontmatter; tools include Write,Edit,Bash
grep -Ei 'trigger type|managed.block|promote_threshold|threshold|dedup|prune|verify.before|root .?CLAUDE|always.?gated|knowledge-ledger|CURATE.md|seed|HARD-GATE|Result:' agents/curator.md   # all mechanisms present
grep -qi 'do NOT commit\|never commit' agents/curator.md && grep -qi 'do NOT archive\|never archive' agents/curator.md   # the step owns commit+archive
! grep -qi 'update .*STATE.md\|write .*STATE' agents/curator.md   # curator writes no STATE (a line saying it deliberately does NOT is fine — adjust grep if so)
wc -l agents/curator.md   # lean — heaviest agent but no padding
```

- [ ] **Step 4: Commit**

```bash
git add agents/curator.md
git commit -m "Add curator agent (durable-knowledge librarian: classify, route, refresh, promote, stage)"
git push origin main
```

### Task 3: reconcile step skill (inline — no agent)

**Files:**
- Create: `skills/reconcile/SKILL.md`

**Interfaces:**
- Consumes: STATE (active feature), config (`mode`, `auto`), `--auto`.
- Produces: **edits SPEC.md + ARCH.md in place** to match the real `git diff` (this is the inline
  exception — the step does the work itself); writes its **own terminal STATE** (Step `reconcile`
  done, Next `/minions:curate`); HITL-pauses unless `auto`. **Does not** emit `RECONCILE.md`, **does
  not** emit knowledge suggestions, **does not** archive (all moved to the curator — supersession note).

Model the step shell on `skills/verify/SKILL.md` (resolve root/config, find feature, STATE, relay) but
the middle is **inline edits**, not an agent dispatch.

- [ ] **Step 1: Write the step skill** (target ≤ ~60 lines — it is small; no loop, no agent)

Frontmatter: `name: reconcile`; trigger `description` (`Use when a feature's been reviewed and its
SPEC/ARCH need folding to what actually shipped before the knowledge pass — "reconcile the spec",
"update SPEC/ARCH to the real diff", or when /minions:feature reaches reconcile…`; minions reconcile
step, normally invoked by `/minions:feature`, runnable directly); `argument-hint: "[--auto]"`;
`arguments: []`.

Body:
1. **Announce:** "Running minions reconcile — folding SPEC and ARCH to what actually shipped."
2. **Resolve state & config:** resolve `<root>`; `STATE.md` missing → `/minions:init`, stop; read
   `config.yml`, extract `mode`, `auto`; apply `--auto`.
3. **Find the active feature:** `<feature>/SPEC.md` missing → `/minions:specify`, stop;
   `<feature>/ARCH.md` missing → note it and continue (architect may have been skipped — reconcile
   only folds what exists). `<feature>/PLAN.md` missing → `/minions:plan`, stop.
4. **STATE ownership (in-progress):** Step `reconcile`, Status `in progress`, Next `/minions:reconcile`
   (self), Updated today.
5. **Reconcile inline (the work — no agent):** read the feature's `git diff` (its commit range /
   changed files), SPEC.md, and ARCH.md. Update **SPEC.md** so its Goal + `AC-n` describe what was
   actually built (a deviation that changed behavior updates the AC; an AC that was dropped is marked,
   not deleted), and **ARCH.md** so its patterns/new-elements/libraries match the real diff (a library
   swapped, a pattern that changed). These two files are feature-local and about to be archived — edit
   them directly. Keep the edits truthful and minimal: reconcile makes the *spec* match *reality*, not
   the reverse (design principle 4). **Do not** touch durable knowledge (skills/CLAUDE.md/rules) — that
   is the curator's job; **do not** emit RECONCILE.md; **do not** archive.
6. **Terminal STATE write (this inline step owns it):** write `<root>/STATE.md` (canonical schema):
   Step `reconcile` **done**, one-line Status (e.g. "SPEC/ARCH folded to diff: 1 AC updated, lib note
   refreshed"), **Next `/minions:curate`**, Updated today.
7. **Relay & pause:** summarize what changed in SPEC/ARCH. Unless `auto`, **stop** and suggest
   `/minions:curate`. If `auto`, state next and continue.

`<HARD-GATE>`: reconcile folds **only** SPEC.md and ARCH.md (the feature-local, about-to-be-archived
pair). It **never** writes durable knowledge (skills, `CLAUDE.md`, rules, DECISIONS — that is the
curator), **never** emits RECONCILE.md, **never** archives, and **never** rewrites reality to match the
spec (only the spec to match reality). If a learning feels durable, that is a note for curate, not an
edit here.

- [ ] **Step 2: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/reconcile/SKILL.md | grep -E '^(name|description|argument-hint):'
grep -Ei 'SPEC|ARCH|git diff|in.?place|Step .reconcile. done|/minions:curate|HARD-GATE' skills/reconcile/SKILL.md
! grep -qi 'RECONCILE.md' skills/reconcile/SKILL.md          # does NOT emit it
! grep -qi 'archive' skills/reconcile/SKILL.md               # does NOT archive
! grep -Eqi 'subagent_type|Agent tool|dispatch' skills/reconcile/SKILL.md   # inline — dispatches no agent
wc -l skills/reconcile/SKILL.md   # lean
```

- [ ] **Step 3: Commit**

```bash
git add skills/reconcile/SKILL.md
git commit -m "Add reconcile step skill (inline: fold SPEC/ARCH to the diff, hand off to curate)"
git push origin main
```

### Task 4: curate step skill (dispatch curator + own commit/archive/STATE)

**Files:**
- Create: `skills/curate/SKILL.md`

**Interfaces:**
- Consumes: STATE (active feature), config (`mode`, `auto`, `docs.knowledge`, `curate.apply`,
  `curate.promote_threshold`, `curate.path`, `curate.cap_lines`, `curate.skills`), `--auto`,
  `--apply=review|auto`.
- Produces: dispatches `minions:curator` (only); **owns commit + archive + terminal STATE**. Under
  `apply: auto` commits the curator's non-gated staged edits (root `CLAUDE.md`/orientation pointer stay
  staged + surfaced), archives the feature folder (`<root>/features/<NNN-slug>` →
  `<root>/features/archive/<NNN-slug>`), writes terminal STATE (workflow complete). Under `apply: review`
  (default) it relays + **pauses before commit**; a re-invocation after you approve commits + archives.
  HITL-pauses unless `auto`.

Model on `skills/review/SKILL.md` (dispatch an agent inside a step that owns terminal STATE) +
`skills/architect/SKILL.md` (agent-dispatch step shell).

- [ ] **Step 1: Write the step skill** (target ≤ ~80 lines — the two-phase finalize pushes it up a
  little, like review's loop did; don't pad)

Frontmatter: `name: curate`; trigger `description` (`Use when a feature's been reconciled and the
project's durable knowledge — skills, CLAUDE.md, rules, DECISIONS — needs updating to match what
shipped, then the feature archived. "Curate the knowledge", "fold learnings into the skills/docs",
"archive this feature", or when /minions:feature reaches curate…`; minions curate step, normally
invoked by `/minions:feature`, runnable directly); `argument-hint: "[--auto] [--apply=review|auto]"`;
`arguments: []`.

Body:
1. **Announce:** "Running minions curate — folding durable learnings into the project's knowledge."
2. **Resolve state & config:** resolve `<root>`; `STATE.md` missing → `/minions:init`, stop; read
   `config.yml`, extract `mode`, `auto`, `docs.knowledge`, and the `curate.*` settings (apply default
   `review`, promote_threshold default 3, path default `.claude/skills`, cap_lines default 150, the
   seed `skills.structural`/`skills.convention` lists); apply `--auto`; effective apply = `--apply`
   else `config.curate.apply` (default `review`).
   - **Knowledge gate:** if `docs.knowledge` is `off`, **skip curation entirely** — write terminal
     STATE (Step `curate` done, Status "knowledge layer off — skipped", Next none), archive the feature
     folder, relay "knowledge layer disabled; feature archived", and stop. (Throwaway-prototype path.)
3. **Find the active feature:** `<feature>/SPEC.md` missing → `/minions:specify`, stop. (ARCH/PLAN
   optional here — curator works from the diff + SPEC.)
4. **Two-phase detection (resumable HITL):** if `<feature>/CURATE.md` **already exists** and the
   working tree has **no uncommitted curator edits** (the human reviewed + committed under `apply:
   review`) → this is the **approval re-invocation**: skip to Step 7 (archive + terminal STATE). Else
   proceed to Step 5 (fresh curation).
5. **STATE ownership (in-progress):** Step `curate`, Status `in progress`, Next `/minions:curate`
   (self), Updated today.
6. **Dispatch the curator.** Use the Agent tool with `subagent_type: minions:curator`. Self-contained
   prompt:
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
   The curator stages edits to the working tree, updates the ledger, writes `<feature>/CURATE.md`, and
   returns its findings. It commits nothing and archives nothing.
7. **Finalize — commit + archive + terminal STATE (this step owns it):**
   - **`apply: auto`:** commit the curator's **non-gated** staged edits — `git add` the touched surface
     files (skills, per-dir `CLAUDE.md`, rules, DECISIONS.md) + `knowledge-ledger.md` + `<feature>/CURATE.md`,
     `git commit -m "chore(knowledge): curate <NNN-slug>"`, `git push`. **Leave staged** any root
     `CLAUDE.md` / orientation-pointer edit (always gated) and surface it for the human. Then **archive**:
     `mkdir -p <root>/features/archive && git mv <root>/features/<NNN-slug> <root>/features/archive/<NNN-slug>`
     (fall back to `mv` if not git-tracked), commit + push the move. Write terminal STATE: Workflow
     `none` / Feature `none` / Step `curate` **done** / Status (e.g. "3 skills refreshed, 1 convention
     promoted; archived") / Next `none` (feature shipped). Relay CURATE.md + any gated edits. Continue.
   - **`apply: review` (default):** **do not commit, do not archive.** Relay `<feature>/CURATE.md` + the
     staged diff (`git diff` / `git status`). **Pause:** tell the human to review the staged edits, then
     either commit them and re-run `/minions:curate` to archive, or re-run with `--apply=auto` to commit
     + archive in one go. Keep STATE at Step `curate` in progress, Next `/minions:curate` (resumable —
     Step 4 detects the approved state on re-invocation). Stop.
8. **Relay** the curator's last `Result / Summary / Deviations-Warnings` block verbatim alongside the
   finalize outcome.

`<HARD-GATE>`: orchestrates + finalizes only. It dispatches **only** `minions:curator` — nothing else.
All knowledge reasoning + authoring belongs to the curator; the step's own writes are limited to git
(commit/archive of the curator's edits, per `apply`) and the terminal STATE. It **never** authors
skills/CLAUDE.md/rules itself, and it **never** commits root `CLAUDE.md`/orientation-pointer edits
unattended (always gated, even under `--apply=auto`).

- [ ] **Step 2: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/curate/SKILL.md | grep -E '^(name|description|argument-hint):'   # argument-hint includes --apply
grep -Ei 'minions:curator|docs.knowledge|apply|review|auto|archive|git mv|CURATE.md|knowledge-ledger|Step .curate. done|root .?CLAUDE|always.?gated|HARD-GATE' skills/curate/SKILL.md
grep -qi 'knowledge.*off' skills/curate/SKILL.md          # knowledge-off skip path present
grep -qi 'do not commit\|does not commit\|never commit' skills/curate/SKILL.md   # review pauses before commit
# dispatches ONLY the curator (no other subagent_type):
grep -oE 'subagent_type: [a-z:]+' skills/curate/SKILL.md | sort -u   # expect only minions:curator
wc -l skills/curate/SKILL.md   # over ~80 is a trim-smell, not a block
```

- [ ] **Step 3: Commit**

```bash
git add skills/curate/SKILL.md
git commit -m "Add curate step skill (dispatch curator; step owns commit, archive, terminal STATE)"
git push origin main
```

### Task 5: wire reconcile + curate into the feature sequence (+ record the QA decision)

**Files:**
- Modify: `skills/feature/SKILL.md` (add `reconcile` then `curate`; after `curate` → complete)
- Modify: `skills/review/SKILL.md` (drop the "reconcile not built / fall back" note — it exists now)
- Modify: `docs/plans/2026-06-19-minions-v2-build.md` (record the QA-dropped decision in increment 3)

**Interfaces:**
- Produces: `/minions:feature` routes the full wired spine `specify → architect → plan → code → verify
  → review → reconcile → curate` (qa intentionally omitted); review cleanly points to `/minions:reconcile`.

- [ ] **Step 1: Update `skills/feature/SKILL.md`**

- Sequence comment (lines ~16–17): the full design sequence still lists qa; update the **"Currently
  wired"** line to `specify → architect → plan → code → verify → review → reconcile → curate` and note
  **qa is intentionally skipped (deferred — see the inc-3c plan)**, and that the spine is now complete.
  Match the existing arrow style (`→`).
- Step 2 "Determine the next step" — advance map: `specify → architect → plan → code → verify → review
  → reconcile → curate`. After `curate` → stop/complete (Step 4).
- Step 3 "Invoke the step skill" — add **`minions:reconcile`** then **`minions:curate`** to the invoke
  list, after `minions:review`.
- Step 4 "After …": update to say the spine is complete after **curate** (feature reconciled, knowledge
  curated, folder archived). Keep it increment-agnostic.
- Keep it a pure router; `wc -l` ≤ ~55 (two more steps may nudge it past 50; tighten prose if so, don't
  add logic).

- [ ] **Step 2: Update `skills/review/SKILL.md`**

Step 5's relay (line ~119–120) currently says reconcile is "not built until increment 3c — fall back to
…". `/minions:reconcile` exists now: suggest it cleanly and drop the fallback parenthetical.

- [ ] **Step 3: Record the QA-dropped decision in the master roadmap**

In `docs/plans/2026-06-19-minions-v2-build.md`, the "### Increment 3 — close the loop" section lists a
`qa` bullet ("Flesh out **qa** agent + `skills/qa/` step…"). Mark it **dropped**: prefix it with
**`~~`**/strike or add a bold `DROPPED (2026-06-24):` lead so the decision is durable — qa is not built,
`agents/qa.md` stays dormant, `config.qa` is a forward-declared no-op, and the wired spine skips it.
Also update the increment-3 "Done when…" line: the spine runs its **wired** steps end-to-end (qa
excluded).

- [ ] **Step 4: Validate**

```bash
grep -q 'specify → architect → plan → code → verify → review → reconcile → curate' skills/feature/SKILL.md   # comment + advance map
grep -q 'minions:reconcile' skills/feature/SKILL.md && grep -q 'minions:curate' skills/feature/SKILL.md       # both in invoke list
! grep -q 'minions:qa' skills/feature/SKILL.md                                                                # qa stays out
! grep -qi 'not built until increment 3\|fall back to .*reconcile' skills/review/SKILL.md                     # review points cleanly
grep -qiE 'DROPPED|~~.*qa|qa.*dropped' docs/plans/2026-06-19-minions-v2-build.md                              # decision recorded
wc -l skills/feature/SKILL.md   # ≤ ~55
```

- [ ] **Step 5: Commit**

```bash
git add skills/feature/SKILL.md skills/review/SKILL.md docs/plans/2026-06-19-minions-v2-build.md
git commit -m "Wire reconcile + curate into the feature spine; record QA-dropped decision"
git push origin main
```

### Task 6: end-to-end UAT (3c)

**Files:** none (manual verification). This is the increment's real "test".

- [ ] **Step 1: Reload the plugin**

In a fresh test session: confirm `/minions:reconcile` and `/minions:curate` are available skills
(`/plugin update minions` + `/reload-plugins` if needed).

- [ ] **Step 2: Run the spine to the end on a small request**

In a throwaway repo (or `~/Projects/test-minions` with a new feature): `/minions:feature "<a small
feature>"`. Walk the HITL pauses all the way:
`specify → architect → plan → code → verify → review → reconcile → curate`. (If a live run isn't
feasible, run a by-hand UAT against a controlled scenario, as 3b did — document which.)

- [ ] **Step 3: Confirm the new behavior held**

- **reconcile ran after review:** SPEC/ARCH were folded to the real diff (introduce one deviation
  during code — e.g. a renamed function or swapped lib — and confirm reconcile updates the matching
  AC/ARCH note); **no `RECONCILE.md`** was written; the feature folder was **not** archived by
  reconcile; STATE ended Step `reconcile` done, Next `/minions:curate`.
- **curate ran after reconcile:** the curator classified learnings, refreshed a structural skill
  (e.g. `tech-stack`/`architecture`) from source, recorded a candidate convention to
  `knowledge-ledger.md` (and did **not** promote it on a single observation — confirm the threshold),
  wrote `<feature>/CURATE.md`, and **staged** edits. Under `apply: review` the step **paused before
  commit**; under `apply: auto` it committed non-gated edits and **left any root `CLAUDE.md` edit
  staged + flagged**.
- **archive + terminal STATE:** after approval/auto, the feature folder moved to
  `features/archive/<NNN-slug>` and STATE reported the feature shipped (Workflow/Feature `none`).
- **sequence + STATE:** `/minions:status` reports reconcile then curate after review; the
  inc-2/3a/3b contract still holds (ARCH.md, `Covers: AC-n`, atomic commits, `## Verification`
  verdicts, review findings).
- **qa is absent:** `/minions:feature` never routes to a qa step (decision held).

- [ ] **Step 4: Capture friction**

`/minions:feedback "<anything that felt off>"` — especially: did the curator's threshold feel right
(no premature rule-writing)? Did the `apply: review` two-phase pause→approve→archive flow feel natural
or clunky? Did anti-bloat hold (no blind-append, root `CLAUDE.md` gated)? Was the inline reconcile the
right call vs an agent? These shape any 3d / curator-audit follow-up.

- [ ] **Step 5: Note results in this plan**

Append a short "Increment 3c UAT results" section to this file, then commit:

```bash
git add docs/plans/2026-06-24-minions-v2-inc3c-reconcile-curate.md
git commit -m "Record increment 3c UAT results"
git push origin main
```

---

## Self-review

- **Spec coverage (design § by §):** §4 step 8 (reconcile — fold SPEC/ARCH to reality, hand off) →
  Task 3; §4 step 9 + curator design whole-doc (curate, curator agent, classify/route/refresh/promote,
  ledger, CURATE.md, apply model, anti-bloat, archive) → Tasks 2 + 4; §5 catalog rows `reconcile` +
  `curate` → Tasks 3–4; §6 roster `curator` #12 (promoted from dormant) → Task 2; §7 artifacts
  (`knowledge-ledger.md` survives archive, per-feature `CURATE.md`, `features/archive/`) → Tasks 1 + 4;
  §8 config `curate:` block → Task 1; §11.19 trigger-type routing + curator as producer → Task 2;
  curator design §5 ledger resolving §13 → Tasks 1–2; §11.13 (no auto loop here — curate is single-pass
  with HITL apply, intentionally). **Dropped:** §4 step 5 (qa) — recorded in Task 5 + the decision
  section; `agents/qa.md` stays dormant, no `qa` step, `config.qa` a no-op. **Superseded:** the master
  roadmap's `RECONCILE.md` + reconcile-archives wording (Task 3 omits both; flagged in the supersession
  note).
- **Placeholder scan:** every task names concrete files, exact section/grep targets, full template
  bodies, and exact commit messages. Pattern-twins are named (curator ↔ `agents/verifier` +
  `agents/reviewer`; reconcile ↔ `skills/verify` shell with inline edits; curate ↔ `skills/review` +
  `skills/architect`). The two non-obvious design calls — (1) the curate **step** owning
  commit+archive+terminal-STATE while the curator only stages (same reason the 3b review step owns its
  terminal STATE: the dispatched agent can't), and (2) the resumable two-phase `apply: review`
  pause→approve→archive — are spelled out in Tasks 2 + 4 and Global Constraints, not left implicit.
- **Consistency:** the wired spine `specify → architect → plan → code → verify → review → reconcile →
  curate` is asserted identically in the feature comment, the feature advance map, and the
  review→reconcile→curate Next-pointer chain. STATE step names (`reconcile`, `curate`) match the
  template enum (Task 1) and the steps' own writes. Config keys (`curate.apply|promote_threshold|path|
  cap_lines|skills`) are named identically in the template (Task 1), the curator dispatch (Task 4), and
  the curator body (Task 2). The §6 return block + `Next: /minions:curate` self-pointer are consistent
  with how 3a/3b agents/steps point forward. The curator gets Write/Edit/Bash (it authors + dedups) but
  is gated from commit/archive by its hard gate, not by tool-withholding — consistent with the design's
  "mutation by agent, but the step finalizes."
