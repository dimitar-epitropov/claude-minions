# minions v2 — Increment 4: the guard (two hooks)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the two plugin-level hooks the design promised (§9): a **guard** (`PreToolUse` on
`Edit|Write` — nudges/denies code edits made outside a minions workflow, per `config.guard`) and a
**reconcile reminder** (`Stop` — a non-blocking nudge when a feature is built-but-not-reconciled), so
that editing a source file outside a workflow triggers the soft steer and `hard` blocks it.

**Architecture:** A plugin-root `hooks/hooks.json` (auto-discovered) wires two POSIX-sh scripts in
`scripts/`. The scripts share one sourced helper (`scripts/minions-hook-lib.sh`) that resolves the
minions root (`.minions-root` → else `docs/minions/`), reads `config.yml`/`STATE.md`, and centralizes
the JSON-in/JSON-out plumbing. This is the **first increment with executable code** — so its "tests"
are real: feed a script crafted stdin JSON against a temp fixture repo and assert stdout + exit code.
No new agents, no step skills, no workflow changes. `config.guard` already exists (increment 1).

**Tech Stack:** POSIX `sh`/`bash` scripts + `jq` for JSON parse/emit (with a **hard fail-safe**: no
`jq`, no root, or any error → `exit 0` silent, never block). Claude Code plugin hooks
(`hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}`). Plugin loads from the `depitropov-plugins` marketplace;
each pushed commit is a new version. Hook mechanics confirmed via Claude Code docs
(https://code.claude.com/docs/en/hooks.md, .../plugins-reference.md) — see Global Constraints.

## Carried-over note: 3c UAT still owed

Increment 3c (reconcile + curate) shipped on main but its **Task 6 UAT was deferred** ("push now,
UAT later"). It is not part of this increment, but it remains outstanding — a real
`/minions:feature` run through `reconcile → curate` should be done when convenient to confirm the
live-plugin path. Increment 4 does not depend on it.

## Global Constraints

The full set lives in `docs/plans/2026-06-19-minions-v2-build.md` (increment 2). The ones that bite
this increment:

- **Two hooks, no more (v1).** Guard + reconcile reminder. No third hook. Each must pay rent (§9,
  §11.16). GSD's 11-hook weight is the anti-pattern.
- **Soft-first, never fight the developer.** `soft` is the default; `hard` only where drift bites;
  `off` is the escape hatch. A guard that fights daily gets disabled, and a disabled guard enforces
  nothing (§11.16, principle 8).
- **FAIL-SAFE is absolute.** A hook is infrastructure that runs on *every* edit/stop for *every*
  plugin holder. Any failure mode — `jq` absent, unreadable STATE, malformed JSON, unexpected path,
  script error — MUST resolve to **`exit 0` with empty stdout (silent allow)**. A hook bug must never
  block an edit or break a session, **even in `hard` mode**. When in doubt, stay silent.
- **Self-scoping.** Plugin-level hooks only ever fire for someone who has minions installed (§7, §9).
  The guard additionally **only acts in a minions-*initialized* repo** (a resolvable `<root>/config.yml`
  exists); in any other repo it is silent — it must not nag a plugin holder in every unrelated project.
- **Hook input is on STDIN as JSON** (read `input=$(cat)`; do NOT read `$1` — a common doc-example
  error). Fields: `.tool_name`, `.tool_input.file_path` (Edit/Write), `.cwd`, `.hook_event_name`.
  `$CLAUDE_PROJECT_DIR` and `${CLAUDE_PLUGIN_ROOT}` are exported to the process.
- **Hook output schema** (exit 0, JSON on stdout):
  - steer (non-blocking): `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"…"}}`
  - deny (blocking): `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
  - silent allow: exit 0, **no stdout**.
  - **`Stop` reminder must be NON-blocking.** Primary shape (to verify empirically in Task 2 — this is
    the one platform detail the secondary source was least certain about):
    `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"…"}}` at exit 0. **NEVER** emit
    `{"decision":"block"}` and **never** exit 2 from the Stop hook (both force continuation). If testing
    shows `additionalContext` is ignored on `Stop`, fall back to the documented non-blocking surface
    (stderr line + exit 0) and record what worked — but blocking is off the table regardless.
- **Root resolution (replicated from the step skills):** `$CLAUDE_PROJECT_DIR/.minions-root` with
  `path: <dir>` → use it; `disabled` → silent exit; else default `docs/minions/`. Resolve relative to
  the project dir (`.cwd` from stdin, or `$CLAUDE_PROJECT_DIR`), not the plugin dir.
- **STATE parse:** STATE.md `## Now` carries `**Step:** <name>` and `**Status:** <line>`. Active
  workflow ⟺ Step is not `none` (a shipped feature ends at Step `none`). "Built but not reconciled" ⟺
  Step ∈ {`verify`, `review`} (code done, reconcile not yet reached).
- **Scripts must be `chmod +x`** and committed executable. POSIX-portable (`#!/usr/bin/env bash`).
- **No secrets, no network, read-only on the repo.** The hooks only read state and emit JSON; they
  never write files or run git.

---

## Increment 4 — the guard (two hooks)

New files: `scripts/minions-hook-lib.sh` (shared helper), `scripts/guard.sh`, `scripts/reconcile-reminder.sh`,
`hooks/hooks.json`. No changes to agents, step skills, the feature workflow, or templates
(`config.guard` already exists). Optional touch: `.claude-plugin/plugin.json` only if auto-discovery
needs a nudge (it should not — confirm in Task 3).

### Task 1: shared hook lib + the guard script

**Files:**
- Create: `scripts/minions-hook-lib.sh` (sourced helper — not a hook itself)
- Create: `scripts/guard.sh` (the `PreToolUse` guard)
- Create: `scripts/test-guard.sh` (the test harness — temp-fixture cases; this is the task's "tests")

**Interfaces:**
- `minions-hook-lib.sh` exposes (via `source`): `mh_have_jq` (returns 0 if jq present),
  `mh_project_dir <stdin-json>` (echoes the project dir from `.cwd` or `$CLAUDE_PROJECT_DIR`),
  `mh_resolve_root <project_dir>` (echoes the resolved `<root>` abs path, or the literal `DISABLED`,
  or empty if uninitialized), `mh_config_guard <root>` (echoes `off|soft|hard`, default `soft`),
  `mh_state_step <root>` (echoes the STATE `Step` value, lowercased, or `none`). Every function
  fails safe (missing input → benign default).
- `guard.sh` consumes stdin JSON, produces either a steer/deny JSON (exit 0) or nothing (exit 0).

- [ ] **Step 1: Write `scripts/minions-hook-lib.sh`**

`#!/usr/bin/env bash`. Pure functions, no side effects on source. Implement:
- `mh_have_jq() { command -v jq >/dev/null 2>&1; }`
- `mh_project_dir(){ ...}` — given the stdin JSON (passed as `$1`), if `jq` present echo
  `.cwd`; else fall back to `${CLAUDE_PROJECT_DIR:-$PWD}`. Never empty.
- `mh_resolve_root(){ local pd="$1"; ... }` — if `$pd/.minions-root` exists: read its `path:` value
  (echo `$pd/<path>` absolute) or, if it contains `disabled`, echo `DISABLED`. Else if
  `$pd/docs/minions` is a dir, echo `$pd/docs/minions`. Else echo empty (uninitialized). Use `grep`/`sed`
  for the one-line `.minions-root`, not jq (it's YAML-ish).
- `mh_config_guard(){ local root="$1"; ... }` — `grep` the `^guard:` line in `$root/config.yml`,
  extract `off|soft|hard`; default `soft` if absent/unreadable.
- `mh_state_step(){ local root="$1"; ... }` — from `$root/STATE.md`, extract the value after
  `**Step:**` (strip markdown/brackets/whitespace, lowercase); default `none`.

Keep each function a few lines; comment the fail-safe defaults.

- [ ] **Step 2: Write `scripts/guard.sh`**

`#!/usr/bin/env bash`. `set -u` only (NOT `set -e` — we must control every exit and never die
mid-script). Source the lib: `. "$(dirname "$0")/minions-hook-lib.sh"`. Logic, in order, each
unmatched branch falling through to a final silent `exit 0`:

1. `input=$(cat)` — read stdin.
2. `mh_have_jq || exit 0` — no jq ⇒ fail safe silent.
3. `pd=$(mh_project_dir "$input")`; `root=$(mh_resolve_root "$pd")`.
4. `[ "$root" = "DISABLED" ] && exit 0`; `[ -z "$root" ] && exit 0` (uninitialized repo → silent).
5. `[ -f "$root/config.yml" ] || exit 0` (no config ⇒ not really initialized ⇒ silent).
6. `guard=$(mh_config_guard "$root")`; `[ "$guard" = off ] && exit 0`.
7. `fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')`; `[ -z "$fp" ] && exit 0`.
8. **Code-vs-exempt classification** (exempt → `exit 0` silent). Exempt when `$fp`:
   - is under the minions root (`$root/…`) or any `*/docs/minions/*` (framework-managed),
   - ends in `.md`/`.markdown`/`.txt` (docs), or is `CLAUDE.md`/`CLAUDE.local.md`,
   - contains a scratch/transient segment: `/scratch/`, `/tmp/`, `/.git/`, `/node_modules/`, `/dist/`,
     `/build/`, `/.minions-root`.
   Everything else is treated as code. (Heuristic errs toward exempting — silence beats nagging.)
9. **Active-workflow check:** `step=$(mh_state_step "$root")`; `[ "$step" != none ] && exit 0` (a
   workflow is live; it owns these edits — including the coder's writes during the `code` step).
10. **No active workflow + code edit → act per mode.** Build the message once:
    `MSG="No active minions workflow. For code changes, use /minions:quick (small) or /minions:feature (larger) so the work is specced, planned, and reconciled."`
    - `soft`: print `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"<MSG>"}}`, `exit 0`.
    - `hard`: print `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<MSG> (guard: hard — set guard: soft|off in <root>/config.yml to relax)"}}`, `exit 0`.
    Build both with `jq -n --arg msg "$MSG" '…'` so quoting is always valid.

- [ ] **Step 3: Write `scripts/test-guard.sh`** (the task's tests — real, not greps)

`#!/usr/bin/env bash`. For each case: build a temp fixture project dir, write a `docs/minions/config.yml`
(with the case's `guard:` value) and `docs/minions/STATE.md` (with the case's `**Step:**`), pipe a
crafted stdin JSON into `guard.sh` with `CLAUDE_PROJECT_DIR=$fixture`, capture stdout, assert. Cases
(assert exact behavior):
1. **uninitialized repo** (no docs/minions) + Write to `src/a.js` → **empty stdout, exit 0**.
2. **guard: off** + code edit, no workflow → **empty stdout**.
3. **guard: soft**, Step `none`, Write `src/a.js` → stdout has `additionalContext`, no `permissionDecision`.
4. **guard: hard**, Step `none`, Edit `src/a.js` → stdout has `permissionDecision: deny`.
5. **guard: soft**, Step `code` (active workflow), Write `src/a.js` → **empty stdout** (workflow owns it).
6. **guard: soft**, Step `none`, Write `docs/minions/STATE.md` → **empty stdout** (framework file).
7. **guard: soft**, Step `none`, Write `README.md` → **empty stdout** (markdown/doc).
8. **guard: hard** but **jq forced absent** (run with `PATH=` stub) → **empty stdout** (fail-safe; hard must not block on a broken hook).
Print `PASS`/`FAIL` per case and a final tally; exit nonzero if any fail.

- [ ] **Step 4: Validate**

```bash
chmod +x scripts/guard.sh scripts/minions-hook-lib.sh scripts/test-guard.sh
bash -n scripts/minions-hook-lib.sh && bash -n scripts/guard.sh   # syntax OK
bash scripts/test-guard.sh                                         # ALL cases PASS
test -x scripts/guard.sh && echo "guard.sh executable"
grep -q 'exit 0' scripts/guard.sh && ! grep -q 'set -e' scripts/guard.sh   # fail-safe shape, no set -e
grep -q 'additionalContext' scripts/guard.sh && grep -q 'permissionDecision' scripts/guard.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/minions-hook-lib.sh scripts/guard.sh scripts/test-guard.sh
git commit -m "Add guard PreToolUse hook script + shared hook lib + tests (soft/hard/off, fail-safe)"
```
(COMMIT ONLY — pushes are batched at the end of the increment.)

### Task 2: the reconcile-reminder script

**Files:**
- Create: `scripts/reconcile-reminder.sh` (the `Stop` hook)
- Create: `scripts/test-reconcile-reminder.sh` (the test harness)

**Interfaces:**
- Consumes stdin JSON (`Stop` event); reuses `minions-hook-lib.sh` (`mh_*`). Produces a non-blocking
  `additionalContext` reminder (exit 0) or nothing (exit 0). **Never blocks.**

- [ ] **Step 1: Write `scripts/reconcile-reminder.sh`**

`#!/usr/bin/env bash`, `set -u` (not `-e`). Source the lib. Logic:
1. `input=$(cat)`; `mh_have_jq || exit 0`.
2. `pd=$(mh_project_dir "$input")`; `root=$(mh_resolve_root "$pd")`;
   `[ "$root" = DISABLED ] && exit 0`; `[ -z "$root" ] && exit 0`; `[ -f "$root/STATE.md" ] || exit 0`.
3. `step=$(mh_state_step "$root")`.
4. **Reminder condition:** `case "$step" in verify|review) ;; *) exit 0 ;; esac` — only when the
   feature is built-but-not-reconciled (code done, reconcile not yet reached). Any other step
   (`none`/`code`/`reconcile`/`curate`/…) → silent.
5. Emit (NON-blocking): `jq -n '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:"This feature is built and reviewed but not reconciled — run /minions:reconcile (then /minions:curate) to fold SPEC/ARCH to what shipped and update project knowledge before moving on."}}'`, `exit 0`.
   - **Empirical check (the one platform uncertainty):** during Step 3's tests AND the Task 3 UAT,
     confirm this `Stop` + `additionalContext` shape actually surfaces the line *without blocking*. If
     it does not surface, switch to the documented non-blocking fallback (a single stderr line + `exit
     0`) and note which worked in the report. Under no circumstance use `decision:block` or exit 2.

- [ ] **Step 2: Write `scripts/test-reconcile-reminder.sh`**

Same fixture pattern. Cases:
1. Step `review` → stdout has `additionalContext` mentioning `/minions:reconcile`; assert **no**
   `"decision"` / no `"block"` substring (non-blocking guarantee).
2. Step `verify` → reminder present.
3. Step `none` → **empty stdout**.
4. Step `curate` → **empty stdout** (reconcile already past).
5. Step `code` → **empty stdout** (still building; not "past code").
6. uninitialized repo → **empty stdout**.
7. jq absent → **empty stdout** (fail-safe).
Print PASS/FAIL + tally; nonzero exit on any failure.

- [ ] **Step 3: Validate**

```bash
chmod +x scripts/reconcile-reminder.sh scripts/test-reconcile-reminder.sh
bash -n scripts/reconcile-reminder.sh
bash scripts/test-reconcile-reminder.sh                                  # ALL cases PASS
! grep -qE '"decision"|exit 2|:block' scripts/reconcile-reminder.sh      # never blocks
grep -q 'additionalContext' scripts/reconcile-reminder.sh
test -x scripts/reconcile-reminder.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/reconcile-reminder.sh scripts/test-reconcile-reminder.sh
git commit -m "Add reconcile-reminder Stop hook script + tests (non-blocking, verify|review only)"
```

### Task 3: wire `hooks/hooks.json` (+ confirm auto-discovery)

**Files:**
- Create: `hooks/hooks.json`
- Possibly modify: `.claude-plugin/plugin.json` (ONLY if auto-discovery needs the explicit `"hooks"`
  path — confirm first; prefer no change)

**Interfaces:**
- Produces: the plugin now registers `PreToolUse` (Edit|Write → guard.sh) and `Stop`
  (→ reconcile-reminder.sh), both via `${CLAUDE_PLUGIN_ROOT}`.

- [ ] **Step 1: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/guard.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/reconcile-reminder.sh" }
        ]
      }
    ]
  }
}
```
(Matcher `Edit|Write` intentionally excludes `MultiEdit`/`NotebookEdit` — the design names `Edit|Write`;
notebooks/multi-edit can be added later if drift shows the gap. Note that for a feature-spine edit the
coder runs *inside* a workflow, so Step≠none keeps the guard silent regardless.)

- [ ] **Step 2: Confirm discovery + JSON validity; decide on plugin.json**

```bash
jq . hooks/hooks.json >/dev/null && echo "hooks.json valid JSON"
jq -e '.hooks.PreToolUse[0].matcher == "Edit|Write"' hooks/hooks.json
jq -e '.hooks.PreToolUse[0].hooks[0].command | test("guard.sh")' hooks/hooks.json
jq -e '.hooks.Stop[0].hooks[0].command | test("reconcile-reminder.sh")' hooks/hooks.json
```
Per the docs, `hooks/hooks.json` at the plugin root is auto-discovered — leave `plugin.json` unchanged.
Only if the Task 3 UAT shows the hooks don't load, add `"hooks": "./hooks/hooks.json"` to
`.claude-plugin/plugin.json` and note it.

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "Wire guard (PreToolUse) + reconcile-reminder (Stop) into plugin hooks.json"
```

### Task 4: end-to-end UAT (4) — manual/user-driven

**Files:** none (manual verification). The increment's real "test" beyond the script unit tests.

- [ ] **Step 1: Reload the plugin** (`/plugin update minions` + `/reload-plugins`) in a fresh session.

- [ ] **Step 2: Exercise the guard** in a throwaway repo with minions initialized (`/minions:init`,
  guard `soft`), no active workflow:
  - Edit a source file (e.g. `src/foo.js`) directly → **soft nudge** appears (additionalContext
    steering to `/minions:quick`/`/minions:feature`); the edit still proceeds.
  - Set `config.yml` `guard: hard`, retry the edit → **denied** with the reason message.
  - Set `guard: off`, retry → silent, edit proceeds.
  - Edit `README.md` / a `docs/minions/**` file (soft) → **no nudge** (exempt).
  - Start a workflow (`/minions:feature`), reach the `code` step → confirm the coder's edits during the
    workflow are **not** nagged (Step≠none).
  - Edit a code file in a repo with **no** minions setup → **no nudge** (self-scoped to initialized repos).

- [ ] **Step 3: Exercise the reconcile reminder:** with a feature mid-flight at Step `verify`/`review`
  (built, not reconciled), end the turn → a **one-line non-blocking** reminder to run
  `/minions:reconcile` appears, and the session still stops normally (never blocked). Confirm no
  reminder fires when Step is `none`/`curate`. **Confirm the `Stop` additionalContext shape worked**
  (the empirical check from Task 2); if it didn't, record what the fallback was.

- [ ] **Step 4: Capture friction** — `/minions:feedback "<anything off>"`: did the soft nudge feel
  helpful or naggy? Did `hard` ever block something it shouldn't (fail-safe holds)? Was the exempt
  heuristic right (any false nags on generated/config files)? Did the Stop reminder over-fire?

- [ ] **Step 5: Note results + push.** Append an "Increment 4 UAT results" section to this file, then:
```bash
git add docs/plans/2026-06-30-minions-v2-inc4-guard-hooks.md
git commit -m "Record increment 4 UAT results"
git push origin main   # batched push of the whole increment
```

---

## Self-review

- **Spec coverage (design § by §):** §9 hook 1 (guard, `PreToolUse` Edit|Write, soft/hard/off, "active
  workflow?" + "is it code?") → Tasks 1 + 3; §9 hook 2 (reconcile reminder, `Stop`, mid-flight past
  code, never blocks) → Tasks 2 + 3; §9 "plugin-level hooks.json, agents can't carry hooks" → Task 3;
  §7 self-scoping / framework footprint (only fires for plugin holders; guard further scoped to
  initialized repos) → Global Constraints + guard Step 4–5; §11.16 steering-over-blocking
  (additionalContext default, deny only on hard) → Task 1 Step 2; §8 `config.guard` consumed → Task 1
  (no new config key). **Deferred (named, not accidental):** MultiEdit/NotebookEdit matchers; a
  per-session debounce on the Stop reminder; any third hook — all out of scope for v1's "two hooks".
- **Placeholder scan:** every script has concrete logic spelled out step-by-step (no "add validation
  here"); the test harnesses enumerate exact cases with exact assertions; `hooks.json` is given in
  full; commit messages are exact. The two genuinely uncertain platform details (Stop additionalContext
  shape; whether plugin.json needs the explicit hooks path) are called out as **empirical checks with a
  defined fallback**, not left as silent assumptions.
- **Consistency:** root-resolution + STATE-parse logic mirrors the step skills (`.minions-root` → else
  `docs/minions/`; `**Step:**` value; Step `none` = no active workflow; `verify`/`review` = built-not-
  reconciled — matching the spine `… verify → review → reconcile → curate`). `config.guard` values
  (`off|soft|hard`) match the template. The fail-safe rule (`exit 0` silent on any doubt) is asserted
  in Global Constraints and implemented as the default fall-through in both scripts. Both scripts share
  one helper (DRY) rather than duplicating root/STATE parsing.
- **Why this is testable, unlike prior increments:** these are real programs, so Tasks 1–2 ship unit
  tests (crafted stdin → asserted stdout/exit) that run in CI-less bash; Task 4 UAT then confirms the
  live hook wiring the unit tests can't reach.
