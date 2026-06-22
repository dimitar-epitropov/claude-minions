# minions v2 — Increment 3a: architect + plan-check loop

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the **architect** step to the `/minions:feature` spine and wire the **plan-check
loop**, so the workflow runs `specify → architect → plan(+check) → code → verify` end-to-end.

**Architecture:** Same three fixed layers as increment 2 (design §3): a thin **step skill**
(`skills/architect/`) builds a self-contained dispatch prompt and dispatches the fresh-context
**architect agent**, which reads SPEC + TECH + codebase and writes `ARCH.md`. The **plan-check
loop** lives entirely in the existing `skills/plan/` step (the only layer that can re-dispatch
agents): after the planner writes `PLAN.md`, the step dispatches the **verifier in `plan` mode**
(already built in increment 2), then handles its criticals/warnings per `config.loops.plan_check`.
This is **increment 3a** of the 3-way "close the loop" split; 3b (qa + review + review-fix loop)
and 3c (reconcile + curate + curator) follow, each after its own UAT.

**Tech Stack:** Markdown skills (`SKILL.md` + YAML frontmatter) and agents (`agents/<name>.md` +
frontmatter). No build, no runtime tests — "tests" are frontmatter/structural greps plus a manual
UAT run of the workflow in a throwaway project. Plugin loads from the `depitropov-plugins`
marketplace; each pushed commit is a new version.

## Global Constraints

The full set lives in `docs/plans/2026-06-19-minions-v2-build.md` (increment 2). Every task here
implicitly includes them. The ones that bite this increment:

- **Layer depth is exactly 3.** Workflow → step → agent. A step skill never invokes another step
  skill; a workflow never dispatches an agent directly; an agent never dispatches an agent (only
  step skills re-dispatch — this is why the plan-check loop lives in the step). (§3)
- **Line caps (soft, smell-not-wall):** workflow skill ≤ ~40 lines, step skill ≤ ~80, ARCH ≤150. (§3, §7)
- **Skill descriptions are TRIGGERS, not summaries** — "Use when…" + symptoms, front-loaded, with
  a note that the step is normally invoked by `/minions:feature` but runnable directly. (§10)
- **Agent return convention** — every agent ends with exactly: `Result: ok|blocked|needs-input` ·
  `Wrote:` · `Summary:` (≤10 lines) · `Deviations/Warnings:` · `Next:`. (§6)
- **State protocol** — every skill reads `<root>/STATE.md` first; every agent writes it last.
  Resolve `<root>` from `.minions-root` (path/disabled) else `docs/minions/`. (§2, §7)
- **Self-contained dispatch** — the step skill hands the agent the feature path, mode, role
  skill-pack, and the exact files to read. The agent never hunts. (§5, §11.14)
- **Mode is the main axis** — `maintain` → architect defaults **scout** (find & follow the existing
  pattern); `vibe` → architect defaults **design** (propose new patterns); prose richness follows
  mode. (§4 step 2, §8)
- **Plugin agents can't carry `permissionMode`/`hooks`** — don't put them in agent frontmatter. (§3)
- **Feature-scoped IDs only** — `AC-n` (spec) and `T-n` (plan) mean nothing outside their feature
  folder. (§7)

---

## Increment 3a — architect + plan-check

Active agents this increment: **architect** (newly fleshed from its dormant stub) and **verifier**
(reused, `plan` mode — already built). The `feature` workflow gains one step (`architect`, after
`specify`) and the `plan` step gains its loop. Everything else from increment 2 is untouched.

### Task 1: ARCH.md feature-artifact template

**Files:**
- Create: `templates/ARCH.md`

**Interfaces:**
- Produces: the artifact shape the architect writes and the planner reads. `ARCH.md` records which
  existing patterns to follow (real paths), what is genuinely new and how, and the libraries
  involved. Cap ≤150 lines. Mirrors the existing `templates/SPEC.md` / `templates/PLAN.md` style
  (header comment about mode-conditional prose, bracketed prompts, soft cap stated).

- [ ] **Step 1: Write `templates/ARCH.md`**

Must contain these sections, with bracketed prompts (no real content — it's a template):
- Title `# Arch — <feature>` and a one-line **Approach** (the architectural stance in a sentence).
- A header comment (`>` block) like SPEC/PLAN: written terse for a reader who knows the codebase
  (**scout** / maintain), richer for one who doesn't (**design** / vibe); state the ≤150-line cap;
  note that in `scout`/maintain a 10-line ARCH is success, not laziness (design §4 step 2).
- `## Patterns to follow` — existing code the feature should mirror, named by **real path**
  (e.g. `src/routes/users.ts` for route shape). The scout's primary output.
- `## New elements` — what is genuinely new and how to build it (mechanism, not full design). In
  `maintain` this is often empty/short; in `vibe` it carries the design.
- `## Libraries` — dependencies the feature uses: existing ones to reuse, and any new one to add.
  Note inline that **adding a dependency is a human-gated install** (the coder surfaces installs as
  a checkpoint, design §11.6) — ARCH only names it.
- `## Open questions` — anything the architect couldn't settle (e.g. a choice that wants external
  research — the researcher isn't wired yet, so it lands here as a question for the human/planner).

- [ ] **Step 2: Validate**

Run: `test -f templates/ARCH.md && grep -E '^## (Patterns to follow|New elements|Libraries|Open questions)$' templates/ARCH.md`
→ all four section headings present. Confirm by eye: title line, an **Approach** line, the
mode-conditional header comment, the install-is-gated note under Libraries, and `wc -l templates/ARCH.md`
≤ 150.

- [ ] **Step 3: Commit**

```bash
git add templates/ARCH.md
git commit -m "Add ARCH.md feature-artifact template"
git push origin main
```

### Task 2: architect agent (flesh out the dormant stub)

**Files:**
- Modify: `agents/architect.md` (currently a dormant stub — frontmatter is correct, body is a
  one-line placeholder + "not yet wired" note; replace the body)

**Interfaces:**
- Consumes (from dispatch prompt): feature folder path, `mode` (`scout|design`), SPEC.md path,
  TECH.md path, the role skill-pack (`config.skills.architect`), the codebase areas to scan.
- Produces: `<feature>/ARCH.md` (Task 1 shape); updates STATE (Step `architect` done,
  Next `/minions:plan`); returns the §6 block.

- [ ] **Step 1: Rewrite the agent body** (keep the existing frontmatter:
  `name: architect`, the trigger `description`, `tools: Read, Grep, Glob, Write, Edit` — no Bash,
  no permissionMode/hooks; scouting is read/search only)

Body (one-job first sentence; numbered "When invoked:"; §10 conventions):
- **One job:** pick the right patterns and mechanisms — reuse everything that already exists,
  design only what's genuinely new.
- **When invoked:** (1) Read the dispatch prompt — it names the feature folder, the `mode`, the
  SPEC.md path (the contract — its `AC-n` define what must be built), the TECH.md path (the index
  into where conventions live), the skill-pack to invoke-and-obey, and the codebase areas to scan.
  Read those; **before scouting, invoke and obey any skills the dispatch lists** (skill packs,
  §11.17). (2) Branch on `mode`:
  - **scout mode (default in `maintain`):** search the codebase for the existing pattern this
    feature should follow; name each by **real path**; say what to reuse verbatim and what (if
    anything) is new. Conforming to an established pattern you might not have chosen is the job —
    not redesigning it. A 10-line ARCH is success here.
    ```bash
    # illustrative — adapt to the stack; use Grep/Glob, not Bash
    # find the nearest analog to what the feature adds (a route, a model, a handler…)
    ```
  - **design mode (default in `vibe`):** where no precedent exists, propose the new
    pattern/mechanism/abstraction and explain the choice (richer prose — the reader may not know
    the codebase). Still reuse whatever does exist; don't green-field what's already there.
  - Both modes: list **libraries** — existing ones to reuse, and any new dependency to add (mark a
    new dependency as a human-gated install, never assume it's present).
- **Write `<feature>/ARCH.md`** in the Task 1 template shape; adapt prose richness to `mode`; keep
  it ≤150 lines.
- `<HARD-GATE>`: **Reuse over invent; never redesign what SPEC settled; never assume an install.**
  Do not pull in adjacent improvements or future features. Do not reopen SPEC decisions — a
  disagreement is an `## Open questions` note, not a silent redesign. Never write product code or
  commit — ARCH.md (and the STATE update) is your only output. **You cannot dispatch other agents**
  (subagents can't spawn subagents): if a decision needs external/online research, record it under
  `## Open questions` (the researcher flow isn't wired yet) rather than guessing.
- **End of run:** update `<root>/STATE.md` (Step `architect` **done**, one-line Status,
  **Next: `/minions:plan`**), then the §6 return block as the last thing in the reply
  (`blocked` if SPEC unreadable; `needs-input` if SPEC has an architectural gap you can't scout or
  design around; `ok` once ARCH.md is written).

- [ ] **Step 2: Validate**

Run: `awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/architect.md | grep -E '^(name|description|tools):'`
→ valid frontmatter. Then grep the body:
`grep -Ei 'scout|design|reuse|ARCH\.md|Open questions|HARD-GATE|Result:|Next:' agents/architect.md`
→ all present. Confirm the body no longer contains the `Status: defined, not yet wired` stub line:
`! grep -q 'not yet wired' agents/architect.md`.

- [ ] **Step 3: Commit**

```bash
git add agents/architect.md
git commit -m "Flesh out architect agent (scout/design, writes ARCH.md)"
git push origin main
```

### Task 3: architect step skill

**Files:**
- Create: `skills/architect/SKILL.md`

**Interfaces:**
- Consumes: STATE (active feature), config (`mode`, `auto`, `skills.architect`), `--mode` /
  `--auto` flags.
- Produces: dispatches `minions:architect`; relays its §6 block; HITL-pauses unless `--auto`.
  Pattern-twin of `skills/plan/SKILL.md` (read it first as the model).

- [ ] **Step 1: Write the step skill** (≤ ~80 lines)

Frontmatter: `name: architect`; trigger `description` (`Use when a feature's SPEC is settled and
needs its patterns/mechanisms decided before planning…`; note it's the minions architect step,
normally invoked by `/minions:feature` but runnable directly to (re)write the active feature's
`ARCH.md`); `argument-hint: "[--mode=scout|design] [--auto]"`; `arguments: []`.

Body — the common step contract (§5), mirroring `skills/plan/SKILL.md`:
1. **Announce:** "Running minions architect — choosing the patterns and mechanisms."
2. **Resolve state & config:** resolve `<root>` (`.minions-root` path/disabled, else
   `docs/minions/`); if `<root>/STATE.md` missing → tell user to run `/minions:init` and stop; read
   `config.yml`, extract `mode`, `auto`, and `skills.architect`; if `--auto` passed, set auto on.
3. **Find the active feature:** read STATE.md for the active feature folder; if `<feature>/SPEC.md`
   is missing → tell user to run `/minions:specify` first and stop.
4. **STATE ownership (this skill's only STATE write):** set Step `architect`, Status `in progress`,
   Next `/minions:architect` (self), Updated today — so an interrupted run resumes. Do **not** write
   "done" (the agent writes the end-of-run STATE).
5. **Resolve architect mode:** explicit `--mode=scout|design` wins; otherwise default from project
   `mode` — `maintain → scout`, `vibe → design`.
6. **Dispatch** with the Agent tool, `subagent_type: minions:architect`, a self-contained prompt:
   feature folder (absolute), architect mode, SPEC.md path (absolute), TECH.md path (absolute), the
   `skills.architect` pack rendered as *"before working, invoke and obey these skills: …"* (omit the
   line if the pack is empty), and the list of real codebase areas to scan (derive from SPEC's
   Goal/ACs). Instruct: write `ARCH.md`, do not write code.
7. **Relay & pause:** relay the agent's full `Result / Summary / Next` verbatim; surface the
   `ARCH.md` path. Unless `auto` is on, **stop** and suggest `/minions:plan` next. If `auto` is on,
   state the next step and continue.

`<HARD-GATE>`: orchestrates only — never scouts the codebase, never writes ARCH.md, never dispatches
any agent other than `minions:architect`. Domain reasoning belongs to the agent.

- [ ] **Step 2: Validate**

Run: `awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/architect/SKILL.md | grep -E '^(name|description|argument-hint):'`
→ frontmatter ok. `wc -l skills/architect/SKILL.md` ≤ ~80. Grep:
`grep -Ei 'minions:architect|scout|design|--auto|skills\.architect|invoke and obey|HARD-GATE' skills/architect/SKILL.md`
→ all present. Confirm it does **not** itself analyze the codebase or write ARCH content
(no domain reasoning).

- [ ] **Step 3: Commit**

```bash
git add skills/architect/SKILL.md
git commit -m "Add architect step skill (dispatches architect)"
git push origin main
```

### Task 4: wire the plan-check loop into the plan step

**Files:**
- Modify: `skills/plan/SKILL.md` (replace the "plan-check loop (deferred to increment 3)" note with
  the real loop; update the ARCH.md handling; update the hard gate to allow the verifier)

**Interfaces:**
- Consumes: `config.loops.plan_check` (`manual` default | `auto` | `off`), `config.loops.max_iters`
  (default 3). Reuses the **verifier in `plan` mode** (already built — `agents/verifier.md`: plan
  mode reads SPEC+PLAN, emits criticals/warnings in its return block, writes **no** STATE and **no**
  `## Verification`).
- Produces: a checked `PLAN.md` — criticals fed back to the planner, warnings appended to
  `PLAN.md ## Warnings`.

- [ ] **Step 1: Update the ARCH.md handling in the dispatch prompt (Step 3 of the skill)**

The current note says ARCH.md doesn't exist yet ("the architect step arrives in increment 3").
Replace it: ARCH.md now **normally exists** (architect runs before plan). Include its absolute path
in the planner dispatch when `<feature>/ARCH.md` exists; **omit** the line if it's absent (the user
ran `/minions:plan` directly without architect — the planner already tolerates this).

- [ ] **Step 2: Add the plan-check loop** (new Step, after the planner returns, before "Relay & pause")

Read `config.loops.plan_check` and `config.loops.max_iters`. Per-run `--plan-check=auto|manual|off`
overrides config (declare it in `argument-hint`/`arguments`).

- **`off`:** skip the check — the single planner pass stands (the increment-2 behavior).
- **`manual` (default): one checked pass.** Dispatch the verifier with the Agent tool,
  `subagent_type: minions:verifier`, a self-contained prompt naming `mode: plan`, the feature
  folder, and the SPEC.md + PLAN.md paths. Take its returned **criticals** and **warnings** (plan
  mode returns them in the §6 block; it writes nothing itself). Append the warnings to
  `PLAN.md ## Warnings` (one bullet each). If there are **criticals**, re-dispatch
  `minions:planner` **once** with a prompt that includes the original planner context **plus** the
  verifier's criticals as "fix these coverage/grounding gaps, document anything you can't fix as a
  `## Warnings` entry." Then **stop the loop** (manual = one pass; the HITL human is the loop —
  design §8). If criticals remain after that single planner pass, they're surfaced in the relay so
  the human re-runs `/minions:plan`.
- **`auto`: loop to `max_iters` with stall-stop.** Repeat { verifier(`plan`) → if criticals,
  planner(fix) } up to `max_iters` iterations. **Stall-stop:** if the critical count does not
  decrease between two consecutive iterations, stop early (design §11.13). Always append each
  pass's warnings to `## Warnings`. Exit when the verifier reports zero criticals or the cap/stall
  is hit; surface any residual criticals in the relay.

Keep all of this in the step skill — never ask the planner or verifier to manage the loop
(agents can't re-dispatch). The planner's end-of-run STATE write (Step `plan` done, Next
`/minions:code`) is fine to let stand after the last planner pass; the verifier in plan mode writes
no STATE, so nothing to undo.

- [ ] **Step 3: Update the hard gate**

The current gate says "never dispatches any agent other than `minions:planner`." Change it to allow
**`minions:planner` and `minions:verifier` (plan mode only)** — and nothing else. Keep the rest of
the gate (the skill never writes PLAN content or reasons about the spec itself).

- [ ] **Step 4: Validate**

`wc -l skills/plan/SKILL.md` (loop adds length, but it's a step skill — keep it lean, ≤ ~80 is the
target; a little over is a smell to trim, not a wall). Grep:
`grep -Ei 'plan_check|minions:verifier|mode: plan|max_iters|stall|manual|auto|off|## Warnings' skills/plan/SKILL.md`
→ all present. Confirm: `off`/`manual`/`auto` branches all described; the `manual` branch says **one
pass**; the `auto` branch names `max_iters` + stall-stop; the hard gate now lists the verifier.
Confirm the stale "deferred to increment 3" note is gone:
`! grep -q 'deferred to increment 3' skills/plan/SKILL.md`.

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md
git commit -m "Wire plan-check loop into plan step (verifier plan mode)"
git push origin main
```

### Task 5: insert architect into the feature sequence

**Files:**
- Modify: `skills/feature/SKILL.md` (add `architect` to the routed sequence)
- Modify: `agents/specificator.md` (repoint its end-of-run STATE Next)
- Modify: `skills/specify/SKILL.md` (repoint its suggested next step)

**Interfaces:**
- Produces: `/minions:feature` now routes `specify → architect → plan → code → verify`; the
  upstream `specify` step/agent correctly point to `/minions:architect`.

- [ ] **Step 1: Update `skills/feature/SKILL.md`**

- The sequence comment (currently "Increment 2 wires: specify → plan → code → verify. Remainder
  arrives in increment 3."): change the wired set to **`specify → architect → plan → code →
  verify`** and note the remainder (`qa → review → reconcile → curate`) arrives in increments 3b/3c.
- Step 2 "Determine the next step": change the advance map to
  **`specify → architect → plan → code → verify`**.
- Step 3 "Invoke the step skill": add **`minions:architect`** to the invoke list (between
  `minions:specify` and `minions:plan`).
- Keep it a pure router; `wc -l` stays ≤ ~45 (it's a one-line-each change — if it pushes over,
  tighten prose, don't add logic).

- [ ] **Step 2: Update `agents/specificator.md`**

Its end-of-run STATE instruction currently writes **Next: `/minions:plan`** with a note "the next
step is the architect, which doesn't exist yet — so for now write Next: `/minions:plan`." The
architect now exists: change it to **Next: `/minions:architect`** and drop the "doesn't exist yet"
note.

- [ ] **Step 3: Update `skills/specify/SKILL.md`**

Its relay-&-pause line currently suggests `/minions:plan` ("`/minions:architect` arrives in
increment 3"). Change the suggested next step to **`/minions:architect`** and drop the parenthetical.

- [ ] **Step 4: Validate**

Grep the sequence is consistent everywhere:
`grep -q 'specify → architect → plan → code → verify' skills/feature/SKILL.md` (or the ASCII `->`
form, matching the file's existing arrow style) → present in the comment and the advance map.
`grep -q 'minions:architect' skills/feature/SKILL.md skills/specify/SKILL.md agents/specificator.md`
→ all three reference it. `! grep -q "doesn't exist yet" agents/specificator.md` and
`! grep -q 'arrives in increment 3' skills/specify/SKILL.md`. `wc -l skills/feature/SKILL.md` ≤ ~45.

- [ ] **Step 5: Commit**

```bash
git add skills/feature/SKILL.md agents/specificator.md skills/specify/SKILL.md
git commit -m "Insert architect into the feature sequence"
git push origin main
```

### Task 6: end-to-end UAT (3a)

**Files:** none (manual verification). This is the increment's real "test".

- [ ] **Step 1: Reload the plugin**

In a fresh test session (the new skills load when the session starts with the latest plugin):
`/plugin update minions` then `/reload-plugins` if needed. Confirm `/minions:architect` is now an
available skill.

- [ ] **Step 2: Run the spine on a small request**

In a throwaway git repo (a fresh one, or reuse `~/Projects/test-minions` with a new feature):
`/minions:init` (or reuse), then `/minions:feature "<a small feature>"`. Walk the HITL pauses:
specify → **architect** → plan → code → verify.

- [ ] **Step 3: Confirm the new behavior held**

Check, in the active feature folder:
- `ARCH.md` exists, is in the template shape (`## Patterns to follow` / `## New elements` /
  `## Libraries` / `## Open questions`), and matches `mode` (scout → terse, design → richer).
- STATE tracked an `architect` step between `specify` and `plan` (read STATE.md at the architect
  pause; `/minions:status` reports "you are here = architect" then "= plan").
- The **plan-check** ran: after planning, the verifier's plan-mode pass executed; any non-criticals
  landed in `PLAN.md ## Warnings`; criticals (if any) were fed back to a second planner pass. Try a
  deliberately thin SPEC to provoke at least one warning and confirm it appears.
- The rest of the contract still holds (inc-2 checks): `Covers: AC-n`, one commit per task,
  `## Verification` AC-by-AC verdicts.

- [ ] **Step 4: Capture friction**

`/minions:feedback "<anything that felt off>"` for each rough edge — especially: did the architect
add value in `maintain`/scout, or was it noise on a small feature? Did the plan-check loop's manual
single-pass feel right? These shape 3b.

- [ ] **Step 5: Note results in this plan**

Append a short "Increment 3a UAT results" section to this file (what worked, what to fix in 3b),
then commit:

```bash
git add docs/plans/2026-06-22-minions-v2-inc3a-architect.md
git commit -m "Record increment 3a UAT results"
git push origin main
```

---

## Self-review

- **Spec coverage (design § by §):** §4 step 2 (architect: scout/design, ARCH.md, maintain-default
  scout, "10 lines is success", may-need-research) → Tasks 1–3; §4 step 3 (plan-check loop:
  verifier plan mode, criticals→replan, warnings→`## Warnings`, `loops.plan_check` manual/auto,
  max_iters, stall-stop) → Task 4; §5 step catalog rows for `architect` and `plan` → Tasks 3–4; §6
  roster architect (`mode: scout|design`) → Task 2; §7 artifacts ARCH.md (≤150) → Task 1; §8 config
  (`mode` default, `loops.plan_check`, `skills.architect`) → consumed in Tasks 3–4; §11.13 bounded
  loops + stall → Task 4; §11.14 self-contained dispatch → Task 3. Out of scope for 3a (assigned to
  3b/3c): qa, review, review-fix loop, reconcile, curate/curator — explicitly deferred.
- **Placeholder scan:** every task names concrete files, exact section headings, exact grep/awk
  validations, and exact commit messages. No "similar to Task N" — the architect step's pattern
  twin (`skills/plan/SKILL.md`) is named so the implementer reads the real model rather than a
  copied stub.
- **Consistency:** agent name `architect` and step name `architect`; the verifier is reused in
  `plan` mode (the agent already supports it — Task 4 adds no agent change, only the step's loop);
  STATE step names (`architect`, `plan`) and the §6 return labels match increment 2 and the design.
  The `specify → architect → plan → code → verify` sequence is asserted identically in the workflow
  comment, the workflow advance map, the specificator's Next, and the specify step's suggestion
  (Task 5 changes all four together in one commit).
