# minions v2 Build Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the rest of minions v2 — the `/minions:feature` spine and its agents — on top of
the committed increment-1 skeleton, following the design at
`docs/design/2026-06-12-minions-v2-design.md`.

**Architecture:** Three fixed layers (design §3): thin **workflow skills** invoke **step skills**,
which build a self-contained dispatch prompt and dispatch a fresh-context **agent**; agents do the
reading/reasoning/writing and persist everything to `docs/minions/**`. This plan covers
**increment 2 in full** (the executable next chunk); increments 3–5 + README are a roadmap (last
section) to be expanded into their own plans when reached, because minions plans one step deep on
purpose.

**Tech Stack:** Markdown skills (`SKILL.md` + YAML frontmatter) and agents (`agents/<name>.md` +
frontmatter). No build, no runtime tests — "tests" are frontmatter/structural checks plus a manual
UAT run of the skill in a throwaway project. Plugin loads from the `depitropov-plugins` marketplace
(GitHub source); each pushed commit is a new version.

## Global Constraints

Copied from the design; every task implicitly includes these.

- **Layer depth is exactly 3.** Workflow → step → agent. A step skill never invokes another step
  skill; a workflow never dispatches an agent directly. (§3)
- **Line caps (soft, smell-not-wall):** workflow skill ≤ ~40 lines, step skill ≤ ~80, SKILL.md
  < 500; artifacts SPEC ≤150, ARCH ≤150, PLAN ≤400, STATE ≤40, TECH ≤150. (§3, §7)
- **Skill descriptions are TRIGGERS, not summaries** — "Use when…" + symptoms, front-loaded; a
  summary description gets followed instead of the body (CSO failure, §10/§11.12).
- **Agent return convention** — every agent ends its reply with exactly:
  `Result: ok|blocked|needs-input` · `Wrote:` · `Summary:` (≤10 lines) · `Deviations/Warnings:` ·
  `Next:`. (§6)
- **State protocol** — every skill reads `<root>/STATE.md` first; every agent writes it last.
  Resolve `<root>` from `.minions-root` (path/disabled) else `docs/minions/`. (§2, §7)
- **Self-contained dispatch** — the step skill hands the agent everything it needs (feature path,
  mode, question budget, role skill-pack, exact files to read). The agent never hunts. (§5, §11.14)
- **Mode is the main axis** — `maintain` = comply with existing conventions; `vibe` = establish &
  record them. Architect defaults scout (maintain) / design (vibe); prose richness follows mode. (§8)
- **Knowledge lives on native surfaces**, never in `docs/minions/` — root/per-dir `CLAUDE.md`,
  `.claude/rules/`, skills. minions only *proposes* (RECONCILE.md), humans apply. (§7, §11.19)
- **Plugin agents can't carry `permissionMode`/`hooks`** — don't put them in agent frontmatter. (§3)
- **Conventions for writing minions itself** are in design §10 — follow them.
- **Feature-scoped IDs only** — `AC-n` (spec) and `T-n` (plan) mean nothing outside their feature
  folder; no global registry. (§7, §11.4)

---

## Increment 2 — the `/minions:feature` spine

Active agents this increment: **specificator, planner, coder, verifier**. The other seven agent
files are created **thin** (a dormant stub: frontmatter + one-line job + "not yet wired" note) so
the roster's boundaries are locked now and increment 3 only has to flesh them out. The `feature`
workflow this increment wires **specify → plan → code → verify** only (architect/qa/review/reconcile
arrive in increment 3).

### Task 1: Feature-artifact templates (SPEC.md, PLAN.md)

**Files:**
- Create: `templates/SPEC.md`
- Create: `templates/PLAN.md`

**Interfaces:**
- Produces: the two artifact shapes every downstream agent reads/writes. `SPEC.md` defines the
  `AC-n` acceptance-criteria format; `PLAN.md` defines task anatomy + the `## Warnings`,
  `## Deviations`, `## Verification` sections later steps append to.

- [ ] **Step 1: Write `templates/SPEC.md`**

Must contain these sections and nothing bloated (cap ≤150 lines), with bracketed prompts:
- Title `# Spec — <feature>` and a one-line **Goal**.
- `## Acceptance criteria` — numbered EARS-style list: `AC-1: WHEN <trigger>, THE SYSTEM SHALL
  <observable outcome>.` (design §11.4). Note inline that these are the contract the verifier checks.
- `## Clarifications` — dated log of `Q → A` from the interview (spec-kit pattern, §11.3).
- `## Out of scope` — explicit non-goals (the reviewer's stage-1 YAGNI list, §11.8).
- A header comment: written for a reader who doesn't know the codebase in `vibe`, who does in
  `maintain` (§7 writing style).

- [ ] **Step 2: Write `templates/PLAN.md`**

Must contain (cap ≤400 lines), with bracketed prompts:
- Title `# Plan — <feature>` and **Phase goal** copied from SPEC.
- `## Tasks` — checklist; each task `- [ ] **T1: <name>**` with sub-bullets **Do** (files, what,
  how — real paths), **Check** (a runnable command/observation that proves it), **Commit** (exact
  message), **Covers** (`AC-n` back-refs). (§4 step 3, §11.4, §11.7)
- `## Warnings` — plan-check non-criticals land here (§4 step 3).
- `## Deviations` — coder logs auto-fixes here (§11.6).
- `## Verification` — verifier writes AC-by-AC verdicts here (§4 step 6).

- [ ] **Step 3: Validate**

Run: `find templates -name 'SPEC.md' -o -name 'PLAN.md'` → both listed.
Confirm by eye: SPEC has `## Acceptance criteria` with an `AC-1:` example; PLAN has all four
sections and a task with Do/Check/Commit/Covers. No section exceeds the cap.

- [ ] **Step 4: Commit**

```bash
git add templates/SPEC.md templates/PLAN.md
git commit -m "Add v2 feature-artifact templates (SPEC, PLAN)"
git push origin main
```

### Task 2: specificator agent

**Files:**
- Create: `agents/specificator.md`

**Interfaces:**
- Consumes (from dispatch prompt): feature folder path, `mode`, `questions` budget, the user's raw
  request, light codebase context, PRODUCT/TECH paths.
- Produces: `<feature>/SPEC.md` (Task 1 shape); updates STATE; returns the §6 convention.

- [ ] **Step 1: Write the agent**

Frontmatter: `name: specificator`, trigger-style `description` (it's dispatched, but write a real
"Use when…"), `tools: Read, Grep, Glob, Write, Edit` (no Bash needed; no permissionMode/hooks).
Body (one job first sentence; numbered "When invoked:"; §10): run the spec-kit interview (§11.3) —
scan the request for ambiguity, ask **≤ N questions** where N maps from `questions`
(none=0, few≈2, regular≈4, many≈6+), one at a time, multiple-choice **with a recommended option**,
and **edit SPEC.md in place** after each answer, logging `Q → A` under `## Clarifications`. Emit
numbered `AC-n` criteria and an `## Out of scope` list. Adapt prose to `mode`. End by writing STATE
(Step `specify` done, Next `/minions:architect` — note that step lands in inc3, so for now Next is
`/minions:plan`) and the §6 return block. Include a `<HARD-GATE>`: do not invent ACs the user never
confirmed; gray areas become questions or out-of-scope, not assumptions.

- [ ] **Step 2: Validate**

Run: `awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/specificator.md` → valid frontmatter
with `name` + `description`. Grep the body for: the question-budget mapping, "in place", `AC-`,
`Out of scope`, and the five return-convention labels (`Result:` … `Next:`).

- [ ] **Step 3: Commit**

```bash
git add agents/specificator.md
git commit -m "Add specificator agent (spec-kit interview, AC-n output)"
git push origin main
```

### Task 3: planner agent

**Files:**
- Create: `agents/planner.md`

**Interfaces:**
- Consumes: feature path, `mode`, SPEC.md, (ARCH.md when it exists — tolerate absence), codebase.
- Produces: `<feature>/PLAN.md` (Task 1 shape) with tasks that carry `Covers: AC-n`; STATE; §6 block.

- [ ] **Step 1: Write the agent**

Frontmatter: `name: planner`, trigger description, `tools: Read, Grep, Glob, Write, Edit, Bash`
(Bash to inspect the repo, not to commit). Body: read SPEC (source of truth) + ARCH if present +
the real files the feature touches; decompose into **2–7 atomic-commit tasks**, each with
Do/Check/Commit/Covers; **goal-backward self-check** — every `AC-n` is covered by some task or the
plan is incomplete (§4 step 3, §11.4). A task covering no AC is a smell to flag. Plans are
self-contained (§11.14): name real paths/identifiers, never "align X with Y" without the target
state. Write STATE (Step `plan` done, Next `/minions:code`) + §6 block. `<HARD-GATE>`: plan only
this feature, never future ones; do not reopen settled SPEC decisions.

- [ ] **Step 2: Validate**

Frontmatter check (as Task 2). Grep body for: `2–7` (or "2-7"), `Covers`, `goal-backward`,
`atomic`, return labels.

- [ ] **Step 3: Commit**

```bash
git add agents/planner.md
git commit -m "Add planner agent (atomic-commit tasks, AC coverage)"
git push origin main
```

### Task 4: coder agent

**Files:**
- Create: `agents/coder.md`

**Interfaces:**
- Consumes: feature path, PLAN.md (self-contained — reads this and little else), role skill-pack
  list, `tasks` param (`all` | `T<n>..`).
- Produces: code + one commit per task; `## Deviations` entries; STATE; §6 block.

- [ ] **Step 1: Write the agent**

Frontmatter: `name: coder`, trigger description, `tools: Read, Grep, Glob, Write, Edit, Bash`.
Body: **before coding, invoke and obey the skills the dispatch prompt lists** (skill packs,
§11.17). Execute PLAN tasks in order; for each: make the change, run its **Check**, then **one
atomic commit** with the task's message (§11.7). Apply the **deviation rules** (§11.6): auto-fix
bugs / missing-critical / blocking issues inline, **but log every deviation** to `## Deviations`;
**exclude package installs** — surface those as a checkpoint, don't auto-run. Respect CLAUDE.md as
hard constraints. Tick the PLAN checkboxes as commits land (resume = read PLAN + `git log`). Write
STATE (Step `code` done, Next `/minions:verify`) + §6 block. `<HARD-GATE>`: never mark a task done
without running its Check; never bundle two tasks in one commit.

- [ ] **Step 2: Validate**

Frontmatter check. Grep body for: `skill` (packs), `atomic`/`one commit`, `Deviations`, "package"
(the install exclusion), return labels.

- [ ] **Step 3: Commit**

```bash
git add agents/coder.md
git commit -m "Add coder agent (atomic commits, deviation rules, skill packs)"
git push origin main
```

### Task 5: verifier agent

**Files:**
- Create: `agents/verifier.md`

**Interfaces:**
- Consumes: feature path, SPEC.md, PLAN.md, codebase, `mode` param (`plan` | `code`).
- Produces: `## Verification` AC-by-AC verdicts in PLAN.md (in `code` mode) or plan findings (in
  `plan` mode); STATE; §6 block.

- [ ] **Step 1: Write the agent**

Frontmatter: `name: verifier`, trigger description, `tools: Read, Grep, Glob, Bash, Edit`.
Body: **adversarial stance** — do NOT trust the coder's summary; name the "how verifiers go soft"
failure modes (§11.5). `code` mode: for each `AC-n` derive what must be TRUE → EXIST → WIRED, then
check the actual codebase; grep for stubs (`TODO`, `return null`, log-only); classify
**VERIFIED / FAILED / UNCERTAIN** and write verdicts to `## Verification`. `plan` mode (used by the
plan-check loop in inc3): check the plan covers every AC and references real code; emit
criticals vs warnings. No override/debt mechanism — criticals must be fixed (§11.5). Write STATE
(Step `verify` done, Next `/minions:review` → for now `reconcile`/done) + §6 block.

- [ ] **Step 2: Validate**

Frontmatter check. Grep body for: `adversarial`, `TRUE`/`EXIST`/`WIRED`, `VERIFIED`, `FAILED`,
`UNCERTAIN`, both `plan` and `code` modes, return labels.

- [ ] **Step 3: Commit**

```bash
git add agents/verifier.md
git commit -m "Add verifier agent (goal-backward, adversarial, two modes)"
git push origin main
```

### Task 6: the seven dormant agent stubs

**Files:**
- Create: `agents/architect.md`, `agents/qa.md`, `agents/reviewer.md`, `agents/researcher.md`,
  `agents/brainstormer.md`, `agents/debugger.md`, `agents/extender.md`

**Interfaces:**
- Produces: valid agent files so the roster exists and namespaces are claimed. architect/qa/reviewer
  get fleshed out in increment 3; researcher/brainstormer/debugger/extender stay dormant until their
  workflows (increment 6).

- [ ] **Step 1: Write seven thin stubs**

Each: frontmatter (`name`, a trigger `description` summarizing the agent's one job from the §6
roster table, `tools` minimal) + a body of: one-line job, its planned inputs→outputs, and a
`> Status: defined, not yet wired — see design §6/§12.` line. Keep each < ~25 lines. Use the exact
fixed params from the §6 table in the description where they exist (e.g. architect `mode:
scout|design`, verifier-like agents, reviewer `stage`, researcher `depth`).

- [ ] **Step 2: Validate**

Run: `for f in architect qa reviewer researcher brainstormer debugger extender; do
awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/$f.md | grep -q '^name:' && echo "$f ok" ||
echo "$f BAD"; done` → all `ok`.

- [ ] **Step 3: Commit**

```bash
git add agents/architect.md agents/qa.md agents/reviewer.md agents/researcher.md \
  agents/brainstormer.md agents/debugger.md agents/extender.md
git commit -m "Add 7 dormant agent stubs (roster boundaries locked)"
git push origin main
```

### Task 7: step skill — specify

**Files:**
- Create: `skills/specify/SKILL.md`

**Interfaces:**
- Consumes: STATE (active feature), config (`mode`, `questions`, `auto`), the request (`$ARGUMENTS`).
- Produces: dispatches specificator; relays its §6 block; HITL-pauses unless `--auto`. Establishes
  the feature folder `<root>/features/NNN-slug/` if absent.

- [ ] **Step 1: Write the step skill (≤ ~80 lines)**

Frontmatter: `name: specify`, trigger description ("Use when… normally invoked by /minions:feature";
note it's a step), `argument-hint: "[request] [--auto] [--questions=…]"`, `arguments:` for the
fixed params. Body — the common step contract (§5): read STATE+config → resolve `<root>` and knobs
→ if no active feature, create `features/NNN-slug/` (NNN = next zero-padded int; slug from request)
and set it active in STATE → build a **self-contained dispatch prompt** (folder path, mode,
question budget, request, which files to read) → dispatch `subagent_type: specificator` → on
return, relay `Result/Summary/Next`, surface SPEC.md path → **stop for review unless `--auto`**.
Announce "Running minions specify — …". Zero domain reasoning here (that's the agent's).

- [ ] **Step 2: Validate**

Frontmatter check. Confirm body ≤ ~80 lines (`wc -l`), references `specificator`, builds a dispatch
prompt, honors `--auto`, creates the feature folder. Confirm it does NOT do the interview itself.

- [ ] **Step 3: Commit**

```bash
git add skills/specify/SKILL.md
git commit -m "Add specify step skill (dispatches specificator)"
git push origin main
```

### Task 8: step skills — plan, code, verify

**Files:**
- Create: `skills/plan/SKILL.md`, `skills/code/SKILL.md`, `skills/verify/SKILL.md`

**Interfaces:**
- Each follows the same step contract as Task 7, dispatching its agent (planner / coder / verifier),
  passing the right params (code: skill-pack from `config.skills.coder`, `tasks`; verify:
  `mode: code`), relaying the §6 block, HITL-pausing unless `--auto`. `plan`'s loop stays
  **manual** this increment (one checked pass is added in inc3; for now plan just dispatches the
  planner).

- [ ] **Step 1: Write `skills/plan/SKILL.md`** — dispatch planner; pass mode + SPEC/ARCH paths;
  relay; pause. Note in a comment that the plan-check loop (verifier in `plan` mode) is wired in
  increment 3. ≤ ~80 lines.

- [ ] **Step 2: Write `skills/code/SKILL.md`** — read `config.skills.coder` pack and pass it in the
  dispatch prompt as "invoke and obey these"; pass `tasks` param; dispatch coder; relay; pause.

- [ ] **Step 3: Write `skills/verify/SKILL.md`** — dispatch verifier with `mode: code`; relay AC
  verdicts; pause.

- [ ] **Step 4: Validate**

For each: frontmatter check, `wc -l` ≤ ~80, references the right agent, honors `--auto`. Confirm
`code`'s prompt includes the skill-pack instruction.

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md skills/code/SKILL.md skills/verify/SKILL.md
git commit -m "Add plan/code/verify step skills"
git push origin main
```

### Task 9: workflow skill — feature

**Files:**
- Create: `skills/feature/SKILL.md`

**Interfaces:**
- Consumes: STATE+config, the request (`$ARGUMENTS`), `--auto`.
- Produces: routes through the steps by invoking step skills via the Skill tool, in order; relays;
  resumable from STATE. Pure routing, **≤ ~40 lines, zero domain logic** (§3).

- [ ] **Step 1: Write the workflow skill**

Frontmatter: `name: feature`, trigger description (the standard tier — "Use when adding a normal
feature to an existing project…"; include the bidirectional right-size signal: if trivial, suggest
`/minions:quick`), `argument-hint: "[request] [--auto]"`, `arguments:`. Body: read STATE → determine
the current step for the active feature → **invoke the next step skill** (`specify` → `plan` → `code`
→ `verify`) via the Skill tool, passing `$ARGUMENTS`/flags → after each, if `--auto` continue, else
the step already paused; relay and stop. Document the full inc-3 sequence
(specify→architect→plan→code→qa→verify→review→reconcile) in a comment but only wire the four that
exist. `<HARD-GATE>`: never dispatch an agent directly; never edit code itself — it only routes.

- [ ] **Step 2: Validate**

Frontmatter check; `wc -l` ≤ ~45; confirm it invokes step skills (not agents), reads STATE for
resume, honors `--auto`. Confirm it contains no interview/plan/code logic.

- [ ] **Step 3: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "Add /minions:feature workflow skill (specify->plan->code->verify)"
git push origin main
```

### Task 10: end-to-end UAT in a throwaway project

**Files:** none (manual verification). This is the increment's real "test".

- [x] **Step 1: Reinstall the plugin**

```bash
# in the test session:
# /plugin update minions    (version-less HEAD → picks up all pushed commits)
# /reload-plugins
```

- [x] **Step 2: Run the spine on a tiny request**

In a throwaway git repo: `/minions:init vibe`, then `/minions:feature "add a /health endpoint that
returns 200 OK"`. Walk the HITL pauses: specify (answer the interview) → plan → code → verify.

- [x] **Step 3: Confirm the contract held**

Check: `docs/minions/features/001-*/SPEC.md` has `AC-n`; `PLAN.md` tasks carry `Covers: AC-n` and
each became one commit (`git log --oneline`); `## Verification` has AC-by-AC verdicts; STATE tracked
the step at each pause and a fresh `/minions:status` reported the right "you are here". Verify the
guard reminder is absent (no hooks yet — that's inc4).

- [x] **Step 4: Capture friction**

`/minions:feedback "<anything that felt off>"` for each rough edge. These shape increment 3.

- [x] **Step 5: Note results in this plan**

Append a short "Increment 2 UAT results" note to this file (what worked, what to fix in inc3),
commit:

```bash
git add docs/plans/2026-06-19-minions-v2-build.md
git commit -m "Record increment 2 UAT results"
git push origin main
```

### Increment 2 UAT results (2026-06-22)

Run by the user in `~/Projects/test-minions` — a richer test than the planned `/health` toy: a
**Kanban board HTTP API** (TypeScript/Node + SQLite), `vibe` mode, `questions: regular`,
`guard: soft`. `/minions:init vibe` → `/minions:feature`, walked all four HITL pauses. **Approved.**

**Contract held — every check passed:**
- **SPEC** — 17 EARS-style `AC-n` grouped by area; dated `## Clarifications` Q→A log (4 entries);
  `## Out of scope`. The specificator never invented unconfirmed ACs.
- **PLAN** — 6 tasks, each with Do/Check/`Commit:`/`Covers: AC-n`. Every one of AC-1…17 is covered;
  the one no-AC task (T1 scaffold) is explicitly labelled infrastructure, not a silent gap.
- **Atomic commits** — 6 tasks → 6 commits whose messages match the PLAN's `Commit:` lines
  verbatim, plus one trailing `docs:` bookkeeping commit. No task bundling.
- **Verification** — `## Verification` has 17/17 `AC-n: VERIFIED` lines, each citing the concrete
  test that proves it (23/23 tests pass, `tsc` clean).
- **Deviations** — one dated entry (T1 `DB` vs `Database` naming) — confirms the inc-2 final-review
  fix (`458ea58`, "coder dated deviations") works in practice.
- **STATE** — tracked the step at every pause; ended `verify` done, `Next: /minions:reconcile`.
- **Orientation pointer** — `vibe` → block appended to root `CLAUDE.md`, no `CLAUDE.local.md`
  (the new init Step 4 from `989c10f` works). Guard reminder correctly absent (hooks are inc 4).
- No friction logged in the project's `feedback.md`.

**Carry into increment 3 (observations, not failures):**
- Agents grew two useful sections beyond the Task-1 templates: SPEC gained `## Context` and
  `## Assumptions`; PLAN gained `## Orientation for the coder (read first)`. These strengthen
  self-containment (§11.14) — fold them into `templates/SPEC.md` / `templates/PLAN.md` so they're
  sanctioned, not improvised.
- The SPEC `## Assumptions` section sits in mild tension with the specificator's `<HARD-GATE>`
  ("gray areas become questions or out-of-scope, not assumptions"). Here the assumptions were
  reasonable inferences, not invented ACs — but inc 3 should decide explicitly whether Assumptions
  is a legitimate third bucket and reconcile the gate wording with the template.
- `Next: /minions:reconcile` points at a step that doesn't exist until inc 3 — expected, and the
  motivation for inc 3 closing the loop.

---

## Roadmap — increments 3–5 + README (expand into full plans when reached)

Deliberately task-level only. Each becomes its own bite-sized plan after the prior increment's UAT,
so it's informed by what we learned (minions plans one step deep — design §13, principle 3).

### Increment 3 — close the loop
- Flesh out **architect** agent (scout/design by `mode`, may dispatch researcher) + `skills/architect/`
  step; insert after specify in `feature`. Writes `ARCH.md` (add `templates/ARCH.md`).
- Flesh out **qa** agent + `skills/qa/` step (gated by `config.qa`); insert after code.
- Flesh out **reviewer** agent (two-stage: spec-compliance, then quality; consumes
  `config.skills.reviewer`) + `skills/review/` step; insert after verify.
- Wire the **plan-check loop** in `skills/plan/` (planner ⇄ verifier `mode:plan`, `loops.plan_check`
  manual default, `max_iters`, stall-stop) and **review-fix loop** in `skills/review/`.
- **reconcile** inline in a `skills/reconcile/` step: update SPEC/ARCH to the real diff; emit
  `RECONCILE.md` of tagged suggestions (mode-derived: vibe builds, maintain suggests gaps); archive
  the feature folder. Add `templates/RECONCILE.md`.
- Done when `/minions:feature` runs all 8 steps end-to-end on a real work task.

### Increment 4 — the guard (two hooks)
- `hooks/hooks.json`: **guard** (`PreToolUse` on `Edit|Write`; `soft` injects `additionalContext`
  when editing code with no active workflow, `hard` denies, `off` silent — reads `config.guard`);
  **reconcile reminder** (`Stop`; nudge if a feature is past `code` without reconcile). Scripts in
  `scripts/`, using `${CLAUDE_PLUGIN_ROOT}`/`.minions-root` to find state.
- Done when editing a source file outside a workflow triggers the soft nudge, and `hard` blocks.

### Increment 5 — `/minions:quick`
- `skills/quick/SKILL.md` workflow: scope-check inline (upgrade-signal to `/minions:feature` if
  multi-module/new-pattern) → code (same skill packs, atomic commits) → review single-stage →
  doc-touch (micro-reconcile, ask first). `--plan` inserts plan before + verify after. No SPEC, no
  feature folder.
- Done when a one-line fix runs start-to-finish without ceremony but still commits atomically +
  reviews.

### README rewrite
- Replace the stale v1-loop README with the v2 model (tiers, three layers, artifacts, config,
  install). Do this after increment 5 so it documents the real, shipped system (must-have #8).

---

## Self-review

- **Spec coverage (§ by §):** §3 layers → Tasks 7–9 (caps/depth enforced in validation); §4 feature
  spine → Tasks 7–9 wire specify/plan/code/verify, rest in roadmap; §5 step catalog → Tasks 7–8;
  §6 roster → Tasks 2–6 (all 11 files); §7 artifacts → Task 1 (SPEC/PLAN; ARCH/RECONCILE in inc3);
  §8 config consumed by step skills → Tasks 7–9; §9 hooks → inc4; §10 conventions → Global
  Constraints + every "Validate" step; §11 provenance → behaviors cited per task; §12 roadmap →
  this plan's structure. Gaps are intentional and assigned to later increments.
- **Placeholder scan:** roadmap section is explicitly task-level-only by design (not placeholder
  tasks inside the executable increment); increment 2 tasks each carry concrete files, required
  sections, and validation commands. References point to the design spec (self-contained), never to
  "similar to Task N".
- **Consistency:** agent names (specificator/planner/coder/verifier), artifact names
  (SPEC/PLAN/ARCH/RECONCILE), STATE step names, and the §6 return labels are used identically
  across tasks and match the design doc.
