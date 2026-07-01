# minions v2 — Increment 5: `/minions:quick` (the lightweight tier)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/minions:quick` — the lightweight workflow tier (design §4): **discipline without
paperwork**. A small change gets atomic commits, a single-pass review, and a nudge to record any
convention it establishes — but **no SPEC, no feature folder, no STATE ceremony**. The bar is
*unobstructable*: a routine small edit runs `code → review-lite → doc-touch` with **zero pauses**;
pauses appear only when genuinely earned (change looks too big; a convention is worth recording).

**Architecture (Option A — own thin quick steps, decided 2026-07-01):** `/minions:quick` is wired
with its **own** thin step skills rather than by generalizing the feature-spine steps or by breaking
the 3-layer rule. Layering stays `workflow → step → agent` (§3). The feature-spine skills
(`code`/`review`/`reconcile`) are **not touched** — quick's friction budget is under quick's own
control, not inherited from machinery built for the heavy tier. The **agents are the shared unit**
and are reused with small "quick-mode" tolerances:

```
skills/quick/       (workflow, ≤~40 ln) — pure router; parses --plan/--auto; invokes quick step(s)
skills/quick-code/  (step,     ≤~80 ln) — scope-check → coder → reviewer(lite) → doc-touch   [CORE]
skills/quick-plan/  (step,     ≤~55 ln) — --plan only: planner → scratch PLAN; verifier after
```

The **core flow** (Tasks 1–3, 5) is a complete, shippable, UAT-able tier on its own; `--plan`
(Task 4) is a separable add-on that can slip to a follow-up without leaving the core half-built.

**Tech Stack:** Markdown skills (`SKILL.md` + YAML frontmatter) and small edits to existing agent
files (`agents/*.md`). No new agents, **no new config keys** (quick reads existing `mode`, `auto`,
`skills.coder`, `skills.reviewer`, `guard`). No build, no runtime tests — "tests" are
frontmatter/structural checks plus a manual UAT run in a throwaway project. Plugin loads from the
`depitropov-plugins` marketplace; each pushed commit is a new version.

## Global Constraints

The full set lives in `docs/plans/2026-06-19-minions-v2-build.md` (increment 2). The ones that bite
this increment:

- **Layer depth is exactly 3.** Workflow → step → agent. The `quick` workflow is a **pure router**
  (≤~40 ln, zero domain logic); it **never dispatches an agent directly** — all dispatch lives in
  `quick-code`/`quick-plan`. A step never invokes another step. (§3)
- **Line caps (soft):** workflow ≤~40, step ≤~80. Scratch PLAN reuses `templates/PLAN.md` shape
  (≤400) but stripped (no ACs / no `Covers`). (§3, §7)
- **Descriptions are TRIGGERS, not summaries** — front-loaded "Use when…" + symptoms. `quick`'s
  description carries the **bidirectional right-size signal**: for a multi-module/new-pattern change,
  point at `/minions:feature`. (§10)
- **Agent return convention** unchanged — every agent still ends with
  `Result / Wrote / Summary / Deviations-Warnings / Next`. (§6)
- **Stateless by design — the one documented exception to the state protocol.** The common step
  contract says "read STATE first, write STATE last" (§2, §5). `quick` deliberately **does neither**:
  it is a one-shot with no feature folder to resume, so it reads **config only** (never STATE) and
  **writes no STATE**. `/minions:status` is unaffected — quick is orthogonal to the feature spine.
  This exception is justified precisely because it serves the unobstructable bar; it must be stated
  explicitly in the skills so a future maintainer doesn't "fix" it back into ceremony.
- **Guard stays silent during a quick run — for free (no STATE marker needed).** The inc4 guard keys
  on **edit origin** (`agent_id`), not STATE (§9, corrected 2026-07-01). Quick's real code edits are
  made by the **coder subagent** → `agent_id` present → guard silent. The inline `doc-touch` edit
  (main session) only ever touches `CLAUDE.md`/`.claude/rules/*` — already **exempt** (`*.md`, basename
  `CLAUDE.md`; and anything under the resolved root). So quick trips nothing and needs no marker. Task 6
  UAT confirms this live.
- **Self-contained dispatch** — each step hands its agent everything (the change request, mode,
  skill-pack, diff, scratch-PLAN path) so the agent never hunts. (§5, §11.14)
- **Mode axis** — prose richness / knowledge-recording style follows `config.mode` (`maintain` vs
  `vibe`), same as the spine. Scope-check severity does **not** vary by mode. (§8)
- **Knowledge lives on native surfaces, never in `docs/minions/`** — `doc-touch` proposes edits to
  root/per-dir `CLAUDE.md` or `.claude/rules/`, **asks first** (root `CLAUDE.md` always gated), and is
  **silent unless the change clearly earns a rule**. It is a *micro*-reconcile: no curator agent, no
  `RECONCILE.md`, no threshold machinery. (§7, §11.19)
- **Scope-check WARNS, never silently refuses.** Decided 2026-07-01 (overrides the design's literal
  "it stops"): on a big-looking change, ask **once** — "continue in quick, or switch to
  `/minions:feature`?" — then honor the answer. `--auto` auto-proceeds without asking.

---

## Increment 5 — `/minions:quick`

New files: `skills/quick/SKILL.md`, `skills/quick-code/SKILL.md`, `skills/quick-plan/SKILL.md`.
Modified: `agents/coder.md`, `agents/reviewer.md` (core tolerances); `agents/planner.md`,
`agents/verifier.md` (`--plan` tolerances); `docs/design/2026-06-12-minions-v2-design.md` (§4/§13
fold). No new templates, no config changes.

### Task 1: agent quick-mode tolerances (core flow)

**Files:**
- Modify: `agents/coder.md`
- Modify: `agents/reviewer.md`

**Interfaces:**
- `coder` gains a **no-PLAN "quick" mode**: when the dispatch provides a *direct change request*
  instead of a `PLAN.md`, it treats the whole change as **one atomic task** — make it, run a sensible
  check, one commit — with all existing rules intact (skill-packs, `CLAUDE.md` outranks, package-install
  checkpoint, deviation discipline).
- `reviewer` gains **lite-without-SPEC**: in `lite` mode with no `SPEC.md`, it uses the **provided
  change request as the intent** for the compliance angle (there are no `AC-n` to check against).

- [ ] **Step 1: Add coder quick-mode clause**

In `agents/coder.md`, add a short clause (keep the agent well under its size norm) stating: *"**Quick
mode (no PLAN):** if your dispatch prompt provides a direct change to make instead of a
`<feature>/PLAN.md`, treat the entire change as a **single atomic task** — make the change, run a
sensible check (build/test/observation) that proves it, and make **one atomic commit** with a clear
message. There is no PLAN file to tick or read; log any deviation in your **return block** (`##
Deviations` doesn't exist here) instead of a PLAN section. Every other rule still holds: obey the
skill-pack and `CLAUDE.md` (they outrank the request), never auto-install packages (surface as
`needs-input`), never fake a check."* Ensure the existing `<HARD-GATE>` still reads correctly with
both modes (PLAN mode and quick mode).

- [ ] **Step 2: Add reviewer lite-without-SPEC clause**

In `agents/reviewer.md`, extend the existing `lite` description (currently: "collapses to a single
combined pass … used by the `quick` tier (increment 5)") so it handles the **no-SPEC** case: *"In
`lite` mode the dispatch may provide **no `SPEC.md`** (the quick tier has none). When there is no
SPEC, use the **change request in the dispatch prompt as the stated intent** for the compliance angle
— check the diff does what was asked and nothing gratuitously more — and spend the rest of the pass on
quality. Classify findings Critical/Important/Minor with `file:line` as usual."* Do not change the
`both`/stage-1/stage-2 behavior the feature spine relies on.

- [ ] **Step 3: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/coder.md   | grep -q '^name: coder'
awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/reviewer.md | grep -q '^name: reviewer'
grep -qi 'quick mode' agents/coder.md            # no-PLAN clause present
grep -qi 'single atomic task' agents/coder.md
grep -qi 'no .*SPEC\|no-SPEC\|change request' agents/reviewer.md  # lite-without-SPEC present
```
Confirm by eye: the coder's `<HARD-GATE>` and end-of-run block still make sense in both modes; the
reviewer's `both` path is untouched.

- [ ] **Step 4: Commit**

```bash
git add agents/coder.md agents/reviewer.md
git commit -m "Add quick-mode tolerances to coder (no-PLAN) and reviewer (lite without SPEC)"
```
(COMMIT ONLY — pushes are batched at the end of the increment.)

### Task 2: the `quick-code` step skill (the core)

**Files:**
- Create: `skills/quick-code/SKILL.md`

**Interfaces:**
- Consumes: the change request (`$ARGUMENTS`), config (`mode`, `auto`, `skills.coder`,
  `skills.reviewer`), and — when invoked by `quick --plan` — a scratch PLAN path.
- Produces: dispatches `minions:coder` then `minions:reviewer` (lite); does scope-check and doc-touch
  **inline** (no agent). Writes **no STATE**. Relays the agents' `Result/Summary` blocks.

- [ ] **Step 1: Write `skills/quick-code/SKILL.md`** (≤~80 lines)

Frontmatter: `name: quick-code`, trigger description ("Use when… the minions quick code step; normally
invoked by `/minions:quick`"), `argument-hint: "[request] [--auto]"`, `arguments:` for the request.
Announce: **"Running minions quick — code, review, done."** Body:

1. **Resolve config only (NOT STATE).** Resolve the minions root (`.minions-root` `path:` → else
   `docs/minions/`; `disabled` → stop). Read `config.yml`; extract `mode`, `auto`, `skills.coder`,
   `skills.reviewer`. Apply `--auto`. **Do not read or write `STATE.md`** — quick is stateless
   (Global Constraints). If there is no `config.yml`, minions isn't initialized here → tell the user
   to run `/minions:init` and stop.
2. **Scope-check (inline, ask-once).** Judge the request: does it plausibly span **multiple modules**
   or **introduce a new pattern/dependency**? If yes and `auto` is off, **ask once** (one concise
   prompt): *"This looks like it may want `/minions:feature` (it <reason>). Continue in quick, or
   switch?"* — honor the answer (switch → tell them to run `/minions:feature "<request>"` and stop;
   continue → proceed). If `auto` is on, note the signal in the relay and proceed. Never silently
   refuse. If the change is clearly small, say nothing and proceed. **Skip scope-check entirely when a
   scratch PLAN path was passed** (invoked by `quick --plan` — that route already committed to quick).
3. **Dispatch the coder.** Build the skill-pack line from `skills.coder` (non-empty → "Before coding,
   invoke and obey these skills: <list>"; empty → "no project skill-packs configured"). Use the Agent
   tool, `subagent_type: minions:coder`, with a **self-contained** prompt. If a scratch PLAN path was
   passed (from `quick --plan`), pass `PLAN.md: <path>` (PLAN mode); otherwise pass the **direct
   change** (quick mode):
   ```
   Quick mode (no PLAN): make this change as a single atomic task.
   Change: <the request>
   Mode: <maintain|vibe>
   <skill-pack line>
   ```
   Do not implement or commit anything here — that is the coder's job.
4. **Dispatch the reviewer (lite).** After the coder returns `ok`, build the reviewer skill-pack line
   from `skills.reviewer`. Use the Agent tool, `subagent_type: minions:reviewer`, self-contained:
   ```
   Mode: <mode>
   Intent (no SPEC): <the request>
   Git diff: <the coder's commit range / changed files>
   stage: both
   lite: true
   <reviewer skill-pack line, if non-empty>
   ```
   From the reviewer's findings: if there are **Critical/Important** findings and `auto` is off, offer
   **one** coder fix pass (re-dispatch `minions:coder` in quick mode, fix-only prompt: "fix exactly
   these findings, one atomic commit each; change nothing else"); in `auto`, apply the one fix pass
   automatically. **Minor** findings are just listed. Never loop more than one fix pass.
5. **doc-touch (inline micro-reconcile).** Judge whether the change **clearly establishes or breaks a
   convention worth recording** (a new pattern, a naming/style choice, a structural fact). If not,
   **stay silent**. If yes: propose a concrete edit to the right native surface (per-dir `CLAUDE.md`
   / `.claude/rules/*`; never `docs/minions/**`), **ask first** before writing (root `CLAUDE.md`
   **always** gated even under `--auto`; other surfaces auto-apply under `--auto`). Keep it to the one
   surface the learning belongs on. No curator, no `RECONCILE.md`.
6. **Relay & stop.** Relay the coder's and reviewer's `Result/Summary/Deviations` blocks verbatim;
   surface the commits made and any residual findings. This is the single natural stopping point.

- [ ] **Step 2: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/quick-code/SKILL.md | grep -q '^name: quick-code'
[ "$(grep -vcE '^\s*$' skills/quick-code/SKILL.md)" -le 90 ] || echo "over soft cap — trim"
grep -q 'minions:coder' skills/quick-code/SKILL.md && grep -q 'minions:reviewer' skills/quick-code/SKILL.md
grep -qi 'lite: true' skills/quick-code/SKILL.md
grep -qi 'do not read or write .*STATE\|stateless' skills/quick-code/SKILL.md   # stateless documented
grep -qi 'scope-check\|Continue in quick' skills/quick-code/SKILL.md
grep -qi 'doc-touch\|CLAUDE.md' skills/quick-code/SKILL.md
```
Confirm by eye: no STATE read/write; scope-check asks (not refuses); doc-touch asks first + silent by
default; only `coder` and `reviewer` are dispatched.

- [ ] **Step 3: Commit**

```bash
git add skills/quick-code/SKILL.md
git commit -m "Add quick-code step skill (scope-check, coder, reviewer-lite, doc-touch; stateless)"
```

### Task 3: the `quick` workflow skill (router) — core flow end-to-end

**Files:**
- Create: `skills/quick/SKILL.md`

**Interfaces:**
- Consumes: the request (`$ARGUMENTS`), `--plan`, `--auto`.
- Produces: routes to the quick step(s). **Pure router, ≤~40 lines, zero domain logic.** After this
  task the **core** quick flow (no `--plan`) runs end-to-end.

- [ ] **Step 1: Write `skills/quick/SKILL.md`** (≤~40 lines)

Frontmatter: `name: quick`, trigger description — the **lightweight tier**: "Use when the change is a
one-liner / small edit / PR-comment fix / follow-up to a shipped feature — `/minions:quick "…"`.
Discipline (atomic commits, a review, a doc nudge) without paperwork (no SPEC, no feature folder).
**If the change spans multiple modules or introduces a new pattern, use `/minions:feature` instead.**"
`argument-hint: "[request] [--plan] [--auto]"`, `arguments:` for the request. Announce: **"Running
minions quick."** Body:

1. Resolve the minions root (`.minions-root` → else `docs/minions/`; `disabled` → stop). Read
   `config.yml` (for `auto`); **do not touch STATE**. Parse `--plan` and `--auto`.
2. **Route:**
   - **default (no `--plan`):** invoke `minions:quick-code` via the Skill tool, passing the request +
     `--auto` if set.
   - **`--plan`:** invoke `minions:quick-plan` (planner → scratch PLAN → verify-after), which itself
     drives `quick-code` for the code+review middle. *(Wired in Task 4; until then, if `--plan` is
     passed, say "`--plan` not yet available — running plain quick" and fall through to `quick-code`.)*
3. Relay the step's result and stop. `--auto` changes nothing at the router level (the step handles
   its own pauses).

- [ ] **Step 2: Validate**

```bash
awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/quick/SKILL.md | grep -q '^name: quick'
[ "$(grep -vcE '^\s*$' skills/quick/SKILL.md)" -le 45 ] || echo "over router cap — trim"
grep -q 'minions:quick-code' skills/quick/SKILL.md
grep -qi 'minions:feature' skills/quick/SKILL.md          # bidirectional right-size signal in description
! grep -q 'subagent_type' skills/quick/SKILL.md           # router NEVER dispatches an agent directly
grep -qi 'do not touch STATE\|stateless\|for .*auto' skills/quick/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add skills/quick/SKILL.md
git commit -m "Add /minions:quick workflow router (core: scope-check -> code -> review-lite -> doc-touch)"
```

### Task 4: the `--plan` path (ephemeral scratch PLAN) — separable add-on

**Files:**
- Modify: `agents/planner.md`, `agents/verifier.md` (`--plan` tolerances)
- Create: `skills/quick-plan/SKILL.md`
- Modify: `skills/quick/SKILL.md` (replace the `--plan` fall-through stub with the real route)

**Interfaces:**
- `planner` gains a **no-SPEC quick mode**: derive tasks from the **request** directly (no `AC-n`, no
  `Covers` back-refs); write a stripped PLAN to a given path.
- `verifier` gains a **task-backward no-SPEC mode**: with no SPEC/ACs, verify each PLAN task by
  **re-running its Check** and grepping for stubs; classify VERIFIED/FAILED/UNCERTAIN per task.
- `quick-plan` writes `<root>/quick/PLAN.md` (tasks+checks, **no ACs**), drives the code+review middle
  via `quick-code` (passing the scratch PLAN path), then dispatches the verifier task-backward. The
  scratch PLAN is a **transient working file** — overwritten each run, **never archived**, **not
  committed** by the flow (the coder commits code only).

- [ ] **Step 1: Add planner + verifier `--plan` tolerances**

`agents/planner.md`: add a clause — *"**Quick mode (no SPEC):** if the dispatch provides a change
request and a target PLAN path instead of a `SPEC.md`, derive the tasks **from the request** and write
a stripped PLAN there — the usual `- [ ] **T1: …**` tasks with **Do/Check/Commit**, but **no `Covers`
back-refs** (there are no ACs) and no goal-backward-vs-SPEC self-check. Keep it small (this is the
quick tier)."* `agents/verifier.md`: add a clause — *"**Quick mode (no SPEC, task-backward):** if the
dispatch provides a PLAN but **no SPEC**, verify each PLAN task by re-running its **Check** and
grepping the diff for stubs (`TODO`, `return null`, log-only); classify each task
**VERIFIED/FAILED/UNCERTAIN**. There are no `AC-n` to derive from — the tasks are the contract."*
Leave both agents' feature-spine (SPEC-driven) behavior intact.

- [ ] **Step 2: Write `skills/quick-plan/SKILL.md`** (≤~55 lines)

Frontmatter: `name: quick-plan`, trigger description ("the minions quick `--plan` step; normally
invoked by `/minions:quick --plan`"), `argument-hint: "[request] [--auto]"`. Announce: **"Running
minions quick --plan — plan, code, review, verify."** Body: resolve config (not STATE); ensure
`<root>/quick/` exists; **dispatch `minions:planner`** (quick mode, request + `PLAN: <root>/quick/PLAN.md`)
→ surface the scratch PLAN and pause unless `--auto`; **invoke `minions:quick-code`** passing the
scratch PLAN path (so the coder runs PLAN mode + reviewer-lite runs) ; then **dispatch
`minions:verifier`** (task-backward, PLAN path, no SPEC) and relay per-task verdicts. Writes **no
STATE**. Note in a comment that the scratch PLAN is transient (overwritten, never archived, not
committed).

- [ ] **Step 3: Wire `--plan` into the workflow**

In `skills/quick/SKILL.md`, replace the Task-3 `--plan` fall-through stub with the real route:
`--plan` → invoke `minions:quick-plan`. Keep the router ≤~40 lines.

- [ ] **Step 4: Validate**

```bash
grep -qi 'quick mode\|no.*SPEC' agents/planner.md && grep -qi 'no .*Covers\|no `Covers`\|no Covers' agents/planner.md
grep -qi 'task-backward\|no.*SPEC' agents/verifier.md
awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/quick-plan/SKILL.md | grep -q '^name: quick-plan'
grep -q 'minions:planner' skills/quick-plan/SKILL.md && grep -q 'minions:verifier' skills/quick-plan/SKILL.md
grep -q 'minions:quick-code' skills/quick-plan/SKILL.md      # reuses the core middle, no dup dispatch logic
grep -q 'minions:quick-plan' skills/quick/SKILL.md           # router now wires --plan for real
grep -qi 'quick/PLAN.md' skills/quick-plan/SKILL.md
```

- [ ] **Step 5: Commit** (two commits — agents, then the step + wiring)

```bash
git add agents/planner.md agents/verifier.md
git commit -m "Add quick --plan tolerances to planner (no-SPEC) and verifier (task-backward)"
git add skills/quick-plan/SKILL.md skills/quick/SKILL.md
git commit -m "Add quick-plan step + wire --plan into /minions:quick (ephemeral scratch PLAN)"
```

### Task 5: fold decisions into the design doc

**Files:**
- Modify: `docs/design/2026-06-12-minions-v2-design.md`

**Interfaces:** the canonical design reflects what shipped (matches the inc4 pattern of updating the
design as part of the increment).

- [ ] **Step 1: Update §4 quick paragraph + §13 open question**

In §4, update the `/minions:quick` paragraph to record the resolved decisions: **scope-check asks
once then proceeds** (not "stops"); `--plan` uses an **ephemeral scratch PLAN** at `<root>/quick/PLAN.md`
(tasks+checks, no ACs; verify is task-backward; overwritten, never archived); quick is **stateless**
(reads config, not STATE; guard silence comes from edit-origin, so no marker is needed); `doc-touch`
is **silent unless a convention is clearly earned**, asks first, root `CLAUDE.md` always gated. In §13,
mark the parked question *"Should `--auto` also lower interaction budget"* as still orthogonal, and note
the "auto-detect editing an archived feature / offer to reopen" question stays **parked** (not built in
inc5).

- [ ] **Step 2: Validate**

```bash
grep -qi 'scratch PLAN\|<root>/quick' docs/design/2026-06-12-minions-v2-design.md
grep -qi 'asks once\|ask once\|warns' docs/design/2026-06-12-minions-v2-design.md
```

- [ ] **Step 3: Commit**

```bash
git add docs/design/2026-06-12-minions-v2-design.md
git commit -m "Fold inc5 quick decisions into design §4 (scope-check, scratch PLAN, stateless, doc-touch)"
```

### Task 6: end-to-end UAT — manual/user-driven

**Files:** none (manual verification). The increment's real "test".

- [ ] **Step 1: Reload the plugin** (`/plugin update minions` + `/reload-plugins`) in a fresh session.

- [ ] **Step 2: Core flow, small change (the unobstructable bar).** In a throwaway repo with minions
  initialized (`/minions:init`, guard `soft`): run `/minions:quick "<a genuinely small change, e.g.
  rename a constant / fix an off-by-one>"`. Confirm: **zero pauses**; the coder made **one atomic
  commit**; the reviewer ran **lite** (single combined pass) and findings were relayed; `doc-touch`
  stayed **silent** (nothing rule-worthy); **no `STATE.md` write** occurred (diff `docs/minions/STATE.md`
  — unchanged); the **guard never nagged** the coder's edits.

- [ ] **Step 3: Scope-check + doc-touch pauses.** Run `/minions:quick "<a deliberately big-sounding
  request spanning multiple modules>"` → confirm it **asks once** ("continue in quick / switch to
  feature") and honors both answers. Run a change that establishes a real convention → confirm
  `doc-touch` **proposes** a `CLAUDE.md`/rule edit and **asks first** (and that root `CLAUDE.md` is
  gated). Confirm `--auto` skips both asks.

- [ ] **Step 4: `--plan` path.** Run `/minions:quick --plan "<a small-but-multi-step change>"` →
  confirm a scratch `<root>/quick/PLAN.md` is written (tasks+checks, **no `Covers`**), the coder
  executes it task-by-task (one commit each), review-lite runs, and the verifier reports **per-task**
  VERIFIED/FAILED. Confirm the scratch PLAN is **not** committed and is overwritten on a second run.

- [ ] **Step 5: Guard interaction (the free-silence claim).** During the Step 2 run, confirm the
  inc4 guard produced **no** nudge for the coder's edits (edit-origin exemption) and **no** nudge for a
  `doc-touch` `CLAUDE.md` edit (exempt). Optionally set `guard: hard` and re-run quick → the quick flow
  still completes (agent edits aren't main-session).

- [ ] **Step 6: Capture friction** — `/minions:feedback "<anything off>"`: Did quick ever pause when it
  shouldn't (obstruction)? Was scope-check's judgment right (too eager / too lax)? Did `doc-touch`
  over-speak or stay silent when it should have proposed? Did the no-SPEC reviewer-lite give useful
  findings without ACs? For `--plan`: was task-backward verify meaningful without ACs?

- [ ] **Step 7: Note results + push.** Append an "Increment 5 UAT results" section to this file, then:

```bash
git add docs/plans/2026-07-01-minions-v2-inc5-quick.md
git commit -m "Record increment 5 UAT results"
git push origin main   # batched push of the whole increment
```

---

## Self-review

- **Spec coverage (design § by §):** §4 quick tier (scope-check → code → review-lite → doc-touch;
  `--plan` = plan+verify bookends) → Tasks 2–4; §3 three layers / router-has-no-domain-logic → Tasks 2–3
  (caps + `! grep subagent_type` in the router validation); §5 step contract (self-contained dispatch)
  → Tasks 2, 4; §6 agent roster reused, return convention intact → Task 1, 4 (tolerances, not rewrites);
  §7 knowledge on native surfaces (doc-touch → CLAUDE.md/rules, never docs/minions) → Task 2 Step 5;
  §8 config consumed (`mode`/`auto`/`skills.*`/`guard`), **no new keys** → Tasks 2–3; §9 guard silence
  via edit-origin (no marker needed) → Global Constraints + Task 6 Step 5; §10 trigger-style descriptions
  + bidirectional right-size → Task 3; §13 open questions folded → Task 5. Deliberate deviation from §4's
  literal "scope-check stops" → **warns/asks-once** (recorded in Task 5, rationale: the unobstructable
  bar). Deliberate exception to §2/§5 state protocol → **stateless quick** (justified in Global Constraints).
- **Placeholder scan:** every skill body is spelled out step-by-step (no "add logic here"); agent
  tolerances are given as concrete clauses; validation commands are exact; commit messages are exact. The
  one forward-reference (Task 3's `--plan` fall-through stub) is explicitly a **temporary stub replaced in
  Task 4**, and the core flow is fully functional without it — the increment degrades cleanly if `--plan`
  slips.
- **Consistency:** dispatch pattern (build skill-pack line → self-contained prompt → `subagent_type:
  minions:<agent>` → relay `Result/Summary`) mirrors the feature-spine step skills exactly. Root
  resolution (`.minions-root` → else `docs/minions/`) matches every other skill. `lite: true` matches the
  reviewer's existing quick-tier hook. The stateless + edit-origin-silence claims are consistent with the
  inc4 guard as actually shipped (keys on `agent_id`, not STATE).
- **Why the core is separable:** Tasks 1–3 + 5 deliver a complete, shippable, UAT-able `/minions:quick`
  with no `--plan`. Task 4 is an independent add-on (its own agent tolerances + one step + one wiring
  line) that can be deferred to a follow-up increment without leaving anything half-built — matching the
  "plan one step deep, ship in shippable slices" principle (design §13).
