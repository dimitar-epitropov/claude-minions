# minions v2 — Increment 3b: review (two-stage) + review-fix loop

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the **review** step (two-stage compliance→quality, after verify) with its
**review-fix loop**, so `/minions:feature` runs
`specify → architect → plan(+check) → code → verify → review`.

**Architecture:** Same three fixed layers as before (design §3). One new agent fleshed from its
dormant stub — **reviewer** (two-stage: spec-compliance, then code quality) — dispatched by a thin
`review` step skill. The **review-fix loop** lives in that step skill (the only layer that can
re-dispatch): the reviewer reports findings, the step re-dispatches the **coder** to fix
Critical/Important ones, then re-reviews — governed by `config.loops.review_fix`, mirroring the
plan-check loop built in 3a. This is **increment 3b** of the 3-way "close the loop" split. **qa is
deliberately deferred** (its agent stub stays dormant) to keep this increment small; 3c (reconcile +
curate + curator) follows, after this increment's UAT.

**Tech Stack:** Markdown skills (`SKILL.md` + YAML frontmatter) and agents (`agents/<name>.md` +
frontmatter). No build, no runtime tests — "tests" are frontmatter/structural greps plus a manual
UAT run of the workflow in a throwaway project. Plugin loads from the `depitropov-plugins`
marketplace; each pushed commit is a new version.

## Global Constraints

The full set lives in `docs/plans/2026-06-19-minions-v2-build.md` (increment 2). Every task here
implicitly includes them. The ones that bite this increment:

- **Layer depth is exactly 3.** Workflow → step → agent. A step never invokes another step; a
  workflow never dispatches an agent directly; an agent never dispatches an agent — only step skills
  re-dispatch (this is why the review-fix loop lives in the `review` step). (§3)
- **Line caps (soft, smell-not-wall):** workflow skill ≤ ~45 lines, step skill ≤ ~80. No new artifact
  templates this increment. (§3, §7)
- **Skill descriptions are TRIGGERS, not summaries** — "Use when…", front-loaded, with a note the
  step is normally invoked by `/minions:feature` but runnable directly. (§10)
- **Agent return convention** — every agent ends with exactly: `Result: ok|blocked|needs-input` ·
  `Wrote:` · `Summary:` (≤10 lines) · `Deviations/Warnings:` · `Next:`. (§6)
- **State protocol** — every skill reads `<root>/STATE.md` first; resolve `<root>` from
  `.minions-root` (path/disabled) else `docs/minions/`. Normally the *agent* writes the end-of-run
  STATE; the **one exception this increment** is the `review` step (Task 2), which owns its terminal
  STATE write because its looped agents can't (see that task). (§2, §7)
- **Self-contained dispatch** — the step hands the agent the feature path, mode, role skill-pack, and
  the exact files to read. The agent never hunts. (§5, §11.14)
- **Mode is the main axis** — prose richness and review emphasis follow `mode`
  (`maintain` = comply with existing conventions; `vibe` = establish them). (§8)
- **Skill packs** — the step copies the role's list from `config.skills.reviewer` into the dispatch
  as "before working, invoke and obey these skills" (stage 2 quality). (§8, §11.17)
- **Bounded loops** — `loops.review_fix` (`manual` default | `auto` | `off`), `loops.max_iters`
  (default 3), stall-stop when the unresolved-finding count stops dropping. Criticals block; the rest
  is recorded. (§8, §11.13)
- **Two-stage review** — stage 1 spec-compliance (built exactly what SPEC asked, *including catching
  EXTRA work* against the `## Out of scope` list); stage 2 quality. The YAGNI catch is the point. (§11.8)
- **Plugin agents can't carry `permissionMode`/`hooks`.** (§3)

---

## Increment 3b — review + review-fix loop

New agent this increment: **reviewer** (fleshed from its dormant stub). Reused: **coder** (the
review-fix loop re-dispatches it — no coder change). New step: `review`. The `feature` workflow gains
one step; the sequence becomes `specify → architect → plan → code → verify → review`. All config keys
consumed already exist (`loops.review_fix`, `loops.max_iters`, `skills.reviewer`) from increment 1 —
no config or template changes. **qa is deferred** — `agents/qa.md` stays a dormant stub and is not
wired here.

### Task 1: reviewer agent (flesh out the dormant stub)

**Files:**
- Modify: `agents/reviewer.md` (dormant stub — frontmatter is correct; replace the body)

**Interfaces:**
- Consumes (from dispatch prompt): feature folder path, `mode`, SPEC.md path, the `git diff` of the
  feature's commits, `stage` (`spec|quality|both`, default `both`), `lite` (bool), and the
  `config.skills.reviewer` pack (for stage 2).
- Produces: **findings in its return block** — Critical/Important/Minor, per stage. Writes **no
  files and no STATE** (it is always run inside the `review` step's loop, like the verifier in plan
  mode). It **reports**; it does **not** fix.

- [ ] **Step 1: Rewrite the agent body** (keep the existing frontmatter: `name: reviewer`, the
  trigger `description`, `tools: Read, Grep, Glob, Bash` — no Write/Edit: the reviewer reports, the
  coder fixes)

Mirror `agents/verifier.md`'s adversarial-but-mechanical shape (one-job first sentence; `## Hard
gate`; numbered "When invoked"; stage branches; `## End of run` with the return block — but **no
STATE write**). Body:
- **One job:** two-stage review of a feature's diff — **stage 1 spec-compliance** (built exactly what
  SPEC asked — no less, and *no more*), then **stage 2 code quality**.
- **When invoked:** read the dispatch — feature folder, `mode`, SPEC.md (the `AC-n` contract + the
  `## Out of scope` list), the diff, the `stage`, `lite`, and the skill-pack. Branch on `stage`:
  - **stage 1 — spec-compliance:** compare the diff against SPEC. **Missing** — an `AC-n` not actually
    delivered. **Extra** — work the SPEC didn't ask for; cite the `## Out of scope` list when the
    extra matches a named non-goal (the YAGNI catch a single-stage review misses). **Misunderstood** —
    right area, wrong behavior.
  - **stage 2 — code quality:** **before judging, invoke and obey the skills the dispatch lists**
    (the reviewer pack, e.g. `java-stack:java-review`). Then assess: clean separation, error handling,
    DRY-without-premature-abstraction, edge cases, test quality (assertions that can fail). Cite
    `file:line`.
  - `both` (default) runs stage 1 then stage 2. `lite` collapses to a single combined pass (for the
    `quick` tier — increment 5; the feature review step uses `both`, not `lite`).
- **Classify every finding** Critical / Important / Minor with a `file:line` and a one-line why. Be
  adversarial about compliance (don't rubber-stamp) but accurate about severity (not everything is
  Critical).
- `<HARD-GATE>`: **Report, never fix; never rubber-stamp scope creep.** You make no edits and no
  commits — your entire output is findings in the return block. Stage 1 **must** check the diff
  against the `## Out of scope` list; unrequested work is a finding even if it's well-built. Never
  downgrade a real compliance gap to avoid conflict.
- **End of run:** do **NOT** write STATE (the `review` step owns it — you are always run inside its
  loop). Return the §6 block as the last thing, putting the findings in `Summary` +
  `Deviations/Warnings`:
  ```
  Result: ok | blocked | needs-input
  Wrote: none
  Summary: <≤10 lines — verdict per stage + the finding tally, e.g. "stage1: 1 Important (extra: rate-limit not in SPEC); stage2: 2 Minor">
  Deviations/Warnings: <the findings, each Critical/Important/Minor with file:line; "none" if clean>
  Next: /minions:reconcile
  ```
  Use `blocked` if the diff/SPEC can't be read; `ok` once both stages are done (`ok` does **not** mean
  zero findings — a review that found Criticals is still an `ok` run that did its job). `Next` names
  `/minions:reconcile` (the post-review step; it arrives in increment 3c — the step relays this).

- [ ] **Step 2: Validate**

Run: `awk '/^---$/{c++;next} c==1{print} c==2{exit}' agents/reviewer.md | grep -E '^(name|description|tools):'`
→ valid frontmatter (confirm `tools: Read, Grep, Glob, Bash` — **no** Write/Edit). Then:
`grep -Ei 'stage|spec.?compliance|quality|out of scope|invoke and obey|Critical|Important|Minor|report|HARD-GATE|Result:' agents/reviewer.md`
→ all present. Confirm: `! grep -q 'not yet wired' agents/reviewer.md`; the agent does **not** instruct
a STATE write (`! grep -qi 'update .*STATE.md' agents/reviewer.md` — a line saying it deliberately
does *not* write STATE is fine).

- [ ] **Step 3: Commit**

```bash
git add agents/reviewer.md
git commit -m "Flesh out reviewer agent (two-stage: compliance, quality)"
git push origin main
```

### Task 2: review step skill + review-fix loop

**Files:**
- Create: `skills/review/SKILL.md`

**Interfaces:**
- Consumes: STATE (active feature), config (`mode`, `auto`, `skills.reviewer`, `skills.coder`,
  `loops.review_fix`, `loops.max_iters`), `--auto`, `--review-fix=auto|manual|off`.
- Produces: dispatches `minions:reviewer` (and, to fix findings, re-dispatches `minions:coder`);
  appends residual/Minor findings to `PLAN.md ## Warnings`; **owns the terminal STATE write**
  (Step `review` done, Next `/minions:reconcile`); HITL-pauses unless `--auto`. Combines the
  step-skill shape of `skills/verify/SKILL.md` with the **loop** pattern from `skills/plan/SKILL.md`
  (read both first as models — the loop is a direct analog of plan-check).

- [ ] **Step 1: Write the step skill** (target ≤ ~80 lines; the loop pushes it up like plan's did —
  a little over is an acceptable smell, don't pad)

Frontmatter: `name: review`; trigger `description` (`Use when a feature's been verified and the diff
needs a compliance + quality review before reconcile…`; minions review step, normally invoked by
`/minions:feature`, runnable directly); `argument-hint: "[--auto] [--review-fix=auto|manual|off]"`;
`arguments: []`.

Body:
1. **Announce:** "Running minions review — checking the diff for spec-compliance, then quality."
2. **Resolve state & config:** resolve `<root>`; `STATE.md` missing → `/minions:init`, stop; read
   `config.yml`, extract `mode`, `auto`, `skills.reviewer`, `skills.coder`, `loops.review_fix`,
   `loops.max_iters`; apply `--auto`; effective review-fix mode = `--review-fix` else
   `config.loops.review_fix` (default `manual`).
3. **Find the active feature:** `<feature>/SPEC.md` missing → `/minions:specify`, stop;
   `<feature>/PLAN.md` missing → `/minions:plan`, stop.
4. **STATE ownership (in-progress):** Step `review`, Status `in progress`, Next `/minions:review`
   (self), Updated today.
5. **The review-fix loop** — build the reviewer skill-pack instruction from `skills.reviewer`
   (non-empty → "before stage 2, invoke and obey these skills: <list>"; empty → omit). Dispatch
   `subagent_type: minions:reviewer` with a self-contained prompt: feature folder (abs), mode,
   SPEC.md path (abs), the feature's `git diff` (name the commit range / changed files), `stage: both`,
   `lite: false`, and the skill-pack line. Take the reviewer's findings from its return block
   (Critical/Important/Minor — it writes nothing itself).
   - **off:** do not fix — just relay the findings and go to Step 6.
   - **manual (default): one fix pass.** Append **Minor** findings (and any Critical/Important you
     don't fix) to `PLAN.md ## Warnings` (one bullet each; replace `_None yet._` if present). If there
     are **Critical/Important** findings, re-dispatch `minions:coder` **once** with a self-contained
     prompt that says: *you are applying review fixes (not executing the plan); fix exactly these
     findings, one atomic commit each, log each to `PLAN.md ## Deviations`; do not change anything the
     findings don't name.* Pass the findings + the `skills.coder` pack + feature folder + PLAN path.
     Then **stop the loop** (manual = one pass; the human is the outer loop). Residual Critical/
     Important after the pass are surfaced in the relay.
   - **auto: loop to `max_iters` with stall-stop.** Initialize `prev_unresolved = ∞`. Repeat:
     reviewer(both) → if Critical/Important findings, coder(fix) → next iteration re-reviews. Append
     each pass's Minor findings to `## Warnings`. Stop when zero Critical/Important, or `max_iters`
     hit, or the Critical/Important count `>= prev_unresolved` (stall). Surface residual findings in
     the relay.
6. **Terminal STATE write (this step owns it — the exception to the agent-writes-STATE rule):** the
   reviewer writes no STATE, and a coder re-dispatched for fixes writes `Step code done, Next
   /minions:verify`, which is wrong for where we are. So **after the loop settles, the step writes**
   `<root>/STATE.md`: Step `review` **done**, a one-line Status (e.g. "review clean" or "2 Important
   fixed, 1 Minor noted"), **Next `/minions:reconcile`**, Updated today — overwriting any STATE a
   fix-coder left behind.
7. **Relay & pause:** relay the reviewer's last `Result / Summary / Deviations-Warnings` verbatim;
   surface `PLAN.md ## Warnings` (and `## Deviations` if fixes were applied). Unless `auto`, **stop**
   and suggest `/minions:reconcile` (note: not built until increment 3c — fall back to "feature is
   reviewed; reconcile/curate arrive next"). If `auto`, state next and continue.

`<HARD-GATE>`: orchestrates only — never reviews the diff itself, never writes findings as its own
judgment, never fixes code. It dispatches **only** `minions:reviewer` and `minions:coder` (for
fixes) — nothing else. All review reasoning belongs to the reviewer; all fixing to the coder.

- [ ] **Step 2: Validate**

`awk '/^---$/{c++;next} c==1{print} c==2{exit}' skills/review/SKILL.md | grep -E '^(name|description|argument-hint):'`
→ ok (argument-hint includes `--review-fix`). Grep:
`grep -Ei 'minions:reviewer|minions:coder|review_fix|stage: both|max_iters|stall|## Warnings|## Deviations|Step .review. done|/minions:reconcile|HARD-GATE' skills/review/SKILL.md`
→ all present. Confirm: the `off`/`manual`/`auto` branches are all described; `manual` says **one
pass**; `auto` names `max_iters` + stall; the step writes the terminal STATE itself (Step review
done) and the hard gate allows reviewer + coder only. `wc -l skills/review/SKILL.md` (lean; over ~80
is a trim-smell, not a block).

- [ ] **Step 3: Commit**

```bash
git add skills/review/SKILL.md
git commit -m "Add review step skill with review-fix loop"
git push origin main
```

### Task 3: insert review into the feature sequence

**Files:**
- Modify: `skills/feature/SKILL.md` (add `review` after `verify`)
- Modify: `agents/verifier.md` (repoint its end-of-run STATE Next)
- Modify: `skills/verify/SKILL.md` (repoint its suggested next step)

**Interfaces:**
- Produces: `/minions:feature` now routes `specify → architect → plan → code → verify → review`; the
  upstream `verify` step/agent point to `/minions:review`.

- [ ] **Step 1: Update `skills/feature/SKILL.md`**

- Sequence comment: change the wired set to **`specify → architect → plan → code → verify → review`**
  and note the remainder (`reconcile → curate`) arrives in increment 3c. Match the file's existing
  arrow style (`→`).
- Step 2 "Determine the next step" — advance map: **`specify → architect → plan → code → verify →
  review`**. After `review` → stop (Step 4).
- Step 3 "Invoke the step skill" — add **`minions:review`** to the invoke list, after
  `minions:verify`.
- Step 4 "After …": update to say **review** is the last wired step for now; reconcile and curate
  arrive in a later increment; keep the phrasing increment-agnostic (don't hardcode "increment 3").
- Keep it a pure router; `wc -l` ≤ ~50 (the file already runs ~50; if these additions push it past,
  tighten prose, don't add logic).

- [ ] **Step 2: Update `agents/verifier.md`**

Its end-of-run STATE instruction currently writes **Next: `/minions:reconcile`** as a fallback
because `/minions:review` "doesn't exist yet". `/minions:review` now exists: change the code-mode
end-of-run Next to **`/minions:review`** and drop the "doesn't exist yet / fall back to reconcile"
note. (Leave plan mode unchanged — it still writes no STATE.)

- [ ] **Step 3: Update `skills/verify/SKILL.md`**

It currently suggests `/minions:review` with a fallback note ("not built until increment 3 — fall
back to `/minions:reconcile`…") in both the STATE-ownership comment and the relay/pause line. Remove
the fallback: `/minions:review` exists now — suggest it cleanly, and update the STATE-ownership
comment's parenthetical accordingly.

- [ ] **Step 4: Validate**

`grep -q 'specify → architect → plan → code → verify → review' skills/feature/SKILL.md` → present in
comment and advance map. `grep -q 'minions:review' skills/feature/SKILL.md` → in the invoke list.
`grep -q '/minions:review' agents/verifier.md && ! grep -qi "doesn't exist yet\|fall back to .*reconcile" agents/verifier.md`.
`! grep -qi 'not built until increment 3' skills/verify/SKILL.md`. Confirm **no** `minions:qa` was
added (qa is deferred): `! grep -q 'minions:qa' skills/feature/SKILL.md`. `wc -l skills/feature/SKILL.md` ≤ ~50.

- [ ] **Step 5: Commit**

```bash
git add skills/feature/SKILL.md agents/verifier.md skills/verify/SKILL.md
git commit -m "Insert review into the feature sequence"
git push origin main
```

### Task 4: end-to-end UAT (3b)

**Files:** none (manual verification). This is the increment's real "test".

- [ ] **Step 1: Reload the plugin**

In a fresh test session: confirm `/minions:review` is now an available skill (`/plugin update
minions` + `/reload-plugins` if needed).

- [ ] **Step 2: Run the spine on a small request**

In a throwaway repo (or `~/Projects/test-minions` with a new feature): `/minions:feature "<a small
feature>"`. Walk the HITL pauses: specify → architect → plan → code → verify → **review**.

- [x] **Step 3: Confirm the new behavior held** (by-hand variant — see results below)

- **review ran after verify;** **stage 1** compared the diff to SPEC (try building one unrequested
  extra to confirm stage 1 flags it against `## Out of scope`); **stage 2** ran the quality pass (and
  obeyed `config.skills.reviewer` if set). Findings appeared in the relay; Minors landed in
  `PLAN.md ## Warnings`.
- **review-fix loop:** with a Critical/Important finding, confirm the coder was re-dispatched to fix
  it, the fix was an atomic commit logged to `## Deviations`, and STATE ended **Step `review` done,
  Next `/minions:reconcile`** (not a stray `code`/`verify` STATE from the fix-coder).
- **sequence + STATE:** `/minions:status` reports the review step after verify; the inc-2/3a contract
  still holds (ARCH.md, `Covers: AC-n`, atomic commits, `## Verification` verdicts, plan-check
  warnings).

- [x] **Step 4: Capture friction** (none — see results)

`/minions:feedback "<anything that felt off>"` — especially: did stage-1 catch scope creep? Did the
review-fix loop's manual one-pass feel right? Did the review step's terminal-STATE-overwrite behave
(no stray code-STATE)? These shape 3c.

- [x] **Step 5: Note results in this plan**

Append a short "Increment 3b UAT results" section to this file, then commit:

```bash
git add docs/plans/2026-06-23-minions-v2-inc3b-review.md
git commit -m "Record increment 3b UAT results"
git push origin main
```

### Increment 3b UAT results (2026-06-24)

Run as a **by-hand UAT** (the controller's session held the pre-3b plugin snapshot, so the live
`/minions:feature` plumbing and `minions:reviewer`/`minions:coder` dispatch-by-type couldn't be
triggered). Instead the review step's logic was executed by hand against a controlled scenario in a
throwaway repo (`/tmp/minions-uat-3b-review`): a built `greet` feature (2/2 AC verified) whose diff
carried a **deliberate scope-creep extra** (a `LANGUAGES`/`set_language` i18n scaffold — SPEC lists
"Localization / i18n" under `## Out of scope`) and a **quality bug** (bare `except: pass`). Steps 1–2
(live plugin reload + real spine run) were therefore substituted; a confirmatory live run is
recommended when convenient. **Approved** — the review behavior is sound.

**What held (each 3b behavior exercised for real):**
- **Two-stage reviewer** — dispatched a general-purpose agent following the actual `agents/reviewer.md`.
  **Stage 1** confirmed AC-1/AC-2 delivered and **flagged the i18n scaffold as Extra, citing the
  `## Out of scope` list** (the YAGNI catch — the whole point of stage 1). **Stage 2** flagged the
  bare `except` and the dead code. Findings were classified Critical/Important/Minor with `file:line`,
  reported in the §6 return block; the reviewer **wrote nothing and made no fix**.
- **Review-fix loop (manual = one pass)** — the Minor (None-handling) was appended to
  `PLAN.md ## Warnings`; the two Important findings were fixed by re-dispatching the coder **once**
  (following the actual `agents/coder.md`) with the "you are applying review fixes, not the plan"
  prompt. The coder removed the out-of-scope scaffold (which also eliminated the bare `except`) in
  **one atomic commit** and **logged a dated entry to `## Deviations`**; tests stayed green (2/2). The
  loop then stopped (manual).
- **Terminal STATE write** — written by the *step* (not an agent) in the **canonical STATE.md schema**
  (`## Now`/`## Next`/`## Open`, `**Step:** review`, `**Status:** …`, `Next: /minions:reconcile`) —
  confirming the final-review fix to that write. No stray `code`/`verify` STATE left by the fix-coder.

**Friction:** none surfaced. The two-stage + out-of-scope catch and the manual one-pass loop behaved
exactly as designed.

**Note for 3c / a real run:** the live-plugin path (skill auto-trigger + subagent dispatch-by-type)
was not exercised here; worth a quick real `/minions:feature` run in a fresh session to confirm the
plumbing end-to-end alongside 3a's already-confirmed live run.

---

## Self-review

- **Spec coverage (design § by §):** §4 step 7 (reviewer two-stage compliance→quality, fixes via
  coder) → Tasks 1–2; §5 catalog row `review` (`loops.review_fix`, stage 1/2) → Task 2; §6 roster
  reviewer (`stage: spec|quality|both`, `lite`) → Task 1; §8 config (`loops.review_fix`,
  `loops.max_iters`, `skills.reviewer`, `skills.coder` for the fix pass) → consumed in Task 2 (no new
  keys); §11.8 two-stage YAGNI catch → Task 1 stage 1 + `## Out of scope`; §11.13 bounded loop +
  stall → Task 2. **Deferred:** §4 step 5 (qa) is intentionally out of scope this increment —
  `agents/qa.md` stays dormant, no `qa` step, no `config.qa` gating; it lands in a later increment.
  Also out of scope (→ 3c): reconcile, curate/curator — the `Next: /minions:reconcile` pointers are
  forward-refs the step relays, exactly as 3a left `Next: /minions:review` before this increment.
- **Placeholder scan:** every task names concrete files, exact section/grep targets, and exact commit
  messages. Pattern-twins are named (review step ↔ `skills/verify` + the plan-check loop in
  `skills/plan`, reviewer ↔ `agents/verifier`) so the implementer reads the real model. The one
  non-obvious design call — the review step owning the terminal STATE write because its looped
  reviewer (no STATE) and fix-coder (wrong STATE) can't — is spelled out in Task 2 Step 6 and flagged
  in Global Constraints, not left implicit.
- **Consistency:** the sequence `specify → architect → plan → code → verify → review` is asserted
  identically in the feature comment, the feature advance map, and (by their Next pointers) the
  verify→review chain; Task 3 changes the verifier Next and the verify-step suggestion together.
  STATE step name (`review`) and the §6 return labels match the rest of the framework. The coder is
  reused unchanged — the review-fix loop dispatches it with a "fix these findings" prompt, relying on
  its existing deviation-logging + atomic-commit contract.
