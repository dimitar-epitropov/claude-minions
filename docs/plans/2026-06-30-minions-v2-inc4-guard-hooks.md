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
- **Hook output schema — confirmed against the live doc** (https://code.claude.com/docs/en/hooks.md;
  exit 0, JSON on stdout):
  - PreToolUse `hookSpecificOutput` fields are `permissionDecision` (`allow|deny|ask|defer`),
    `permissionDecisionReason`, `updatedInput`, **and `additionalContext`** (doc-confirmed for
    PreToolUse — *not* a Stop-only field).
  - steer (non-blocking, soft): `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"…"}}`
    — omit `permissionDecision`; the tool proceeds and the message is delivered next to the tool result.
  - deny (blocking, hard): `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
  - silent allow: exit 0, **no stdout**.
  - **`Stop` reminder, NON-blocking — doc-confirmed:** `{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"…"}}`
    at exit 0 ("non-error feedback that continues the conversation"). **NEVER** emit `{"decision":"block"}`
    and **never** exit 2 from the Stop hook (both *prevent stopping* / force continuation).
- **Exit-code semantics — confirmed:** **only exit 2 blocks** (PreToolUse: blocks the tool; Stop:
  prevents stopping). Exit 0 → stdout JSON is processed. **Any other nonzero exit is a NON-blocking
  error** — the action proceeds. So a script crash can never block an edit, even in `hard` mode (the
  central safety claim). Still, **every script must end on an explicit `exit 0`** and capture jq output
  before printing (`out=$(jq -n …) && printf '%s' "$out"; exit 0`) so a jq failure can't leak a nonzero
  exit or a stderr "error" line.
- **Path normalization (mandatory before any path match):** `.tool_input.file_path` is frequently
  **relative to the project dir** (or `./`-prefixed). Normalize first — strip a leading `./`; if not
  absolute, prefix the resolved project dir — then do all exempt/under-root matching on the normalized
  absolute path. (Without this, a relative `docs/minions/STATE.md` edit is misclassified as code and, in
  `hard` mode, *blocked* — a false positive against the framework's own files.)
- **Root resolution (replicated from the step skills, all of which resolve at the *repo root*):** prefer
  **`$CLAUDE_PROJECT_DIR`** (the platform-guaranteed project root) as the project dir; fall back to the
  stdin `.cwd` then `$PWD`. (`.cwd` can be a *subdirectory* the user `cd`'d into — resolving root there
  would miss `docs/minions/` and silently disable the guard.) Then: `<projdir>/.minions-root` with a
  `path:` value → if that value is **absolute** use it as-is, else `<projdir>/<path>` (trim surrounding
  whitespace/quotes, strip inline `#` comments and CR); `disabled` → silent exit; else default
  `<projdir>/docs/minions`.
- **STATE parse (Step AND Status):** STATE.md `## Now` carries `**Step:** <name>` and
  `**Status:** <line>`. The lib extracts both. **Active workflow** (guard stays silent) ⟺ Step is not
  `none` — and the terminal `curate` step **does reset Step to `none`** on a shipped feature (verified:
  inc3c Task 4 terminal STATE is `Step: none`), so the guard self-clears on completion. (Known, accepted
  edge: a feature *abandoned* at a done step keeps Step ≠ `none`, so the guard defers to it until STATE
  is reset — rare, self-heals on the next `/minions:status`/workflow; documented, not fixed in v1.)
  **"Built but not reconciled"** (reconcile reminder fires) ⟺ Step ∈ {`qa`, `verify`, `review`} **or**
  (Step == `code` **and** Status indicates *done*) — i.e. code is complete but reconcile hasn't run.
- **Portability (dev is on macOS/BSD, users vary):** POSIX only — `[[:space:]]` not `\s`, no `grep -P`,
  no GNU-only `sed`. Prefer pure-bash parameter expansion for trimming over `sed`. `#!/usr/bin/env bash`.
- **`set -u` safety:** every environment read uses `${VAR:-default}` (a bare unset `$CLAUDE_PROJECT_DIR`
  under `set -u` aborts the script); quote `"$(dirname "$0")"` and `|| exit 0` the `source` line.
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
- `mh_project_dir(){ local json="$1"; ... }` — **prefer** `${CLAUDE_PROJECT_DIR:-}` (platform-guaranteed
  repo root); if unset, take `.cwd` from the JSON (`jq -r '.cwd // empty' 2>/dev/null`); else `$PWD`.
  Never empty. (Do NOT prefer `.cwd` — it can be a subdir; root files live at the repo root.)
- `mh_resolve_root(){ local pd="$1"; ... }` — if `$pd/.minions-root` exists, extract the `path:` value
  (POSIX: `grep -E '^path:'` then trim whitespace/surrounding quotes, strip inline `#` comment + CR via
  bash param expansion, not GNU sed); if the file/value says `disabled` → echo `DISABLED`; else if the
  path is **absolute** (`/…`) echo it as-is, otherwise echo `$pd/<path>`. If no `.minions-root`: if
  `$pd/docs/minions` is a dir, echo `$pd/docs/minions`; else echo empty (uninitialized). Never use jq
  here (it's YAML-ish).
- `mh_config_guard(){ local root="$1"; ... }` — `grep -E '^guard:'` the `$root/config.yml` line,
  extract `off|soft|hard` (param-expansion trim); default `soft` if absent/unreadable.
- `mh_state_step(){ local root="$1"; ... }` — from `$root/STATE.md`, extract the value after
  `**Step:**` (strip markdown `**`, brackets, whitespace; lowercase via `tr`); default `none`.
- `mh_state_status(){ local root="$1"; ... }` — from `$root/STATE.md`, extract the `**Status:**` line
  value, lowercased; default empty. (Used by the reconcile reminder to tell `code`-in-progress from
  `code`-done.)

Keep each function a few lines; comment the fail-safe defaults. Every env read uses `${VAR:-default}`
(`set -u` safe). Match/trim with POSIX `[[:space:]]` and bash parameter expansion — no `\s`, no `grep -P`.

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
7. `fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)`;
   `[ -z "$fp" ] && exit 0` (no path, or malformed stdin → jq empties → silent).
   **Normalize:** strip a leading `./`; if `$fp` is not absolute (`/…`), prefix `$pd/`. Match on the
   normalized absolute path from here on.
8. **Code-vs-exempt classification** — use a bash `case "$fp" in … esac` with glob patterns (NOT regex,
   NOT external grep), exempt → `exit 0` silent. Exempt when the normalized `$fp`:
   - is under the resolved root (`"$root"/*`) or any `*/docs/minions/*` (framework-managed),
   - ends in `*.md`/`*.markdown`/`*.txt`, or basename is `CLAUDE.md`/`CLAUDE.local.md` (docs),
   - is a generated/lock file: `*/package-lock.json`/`*/yarn.lock`/`*.lock`,
   - contains a scratch/transient segment: `*/scratch/*`, `*/tmp/*`, `*/.git/*`, `*/node_modules/*`,
     `*/dist/*`, `*/build/*`, or basename `.minions-root`.
   Everything else is treated as code. (Heuristic errs toward exempting — silence beats nagging.
   Config files like `*.json`/`*.yml` are intentionally NOT exempt — Task 4 UAT watches for false nags.)
9. **Active-workflow check:** `step=$(mh_state_step "$root")`; `[ "$step" != none ] && exit 0` (a
   workflow is in flight — it owns these edits, including the coder's writes during the `code` step;
   `curate` resets Step→`none` on ship so this re-arms after a feature completes).
10. **No active workflow + code edit → act per mode.** Build the message once:
    `MSG="No active minions workflow. For code changes, use /minions:quick (small) or /minions:feature (larger) so the work is specced, planned, and reconciled."`
    - `soft`: `out=$(jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}') && printf '%s' "$out"; exit 0`.
    - `hard`: `out=$(jq -n --arg m "$MSG (guard: hard — set guard: soft|off in $root/config.yml to relax)" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}') && printf '%s' "$out"; exit 0`.
    Using `jq -n --arg` keeps quoting valid; capturing then printing + the trailing `exit 0` guarantees a
    failed jq can't leak a nonzero exit. **The script's final line is an unconditional `exit 0`.**

- [ ] **Step 3: Write `scripts/test-guard.sh`** (the task's tests — real, not greps)

`#!/usr/bin/env bash`. For each case: build a temp fixture project dir, write a `docs/minions/config.yml`
(with the case's `guard:` value) and `docs/minions/STATE.md` (with the case's `**Step:**`), pipe a
crafted stdin JSON into `guard.sh` with `CLAUDE_PROJECT_DIR=$fixture`, capture stdout, assert. Cases
(assert exact behavior):
1. **uninitialized repo** (no docs/minions) + Write to `src/a.js` → **empty stdout, exit 0**.
2. **guard: off** + code edit, no workflow → **empty stdout**.
3. **guard: soft**, Step `none`, Write `src/a.js` → stdout has `additionalContext`, no `permissionDecision`.
4. **guard: hard**, Step `none`, Edit `src/a.js` → stdout has `permissionDecision":"deny"`.
5. **guard: soft**, Step `code` (active workflow), Write `src/a.js` → **empty stdout** (workflow owns it).
6. **guard: soft**, Step `none`, Write `docs/minions/STATE.md` (absolute path) → **empty stdout** (framework file).
7. **guard: soft**, Step `none`, Write `README.md` → **empty stdout** (markdown/doc).
8. **relative path** — guard: soft, Step `none`, `file_path: "docs/minions/config.yml"` (relative) →
   **empty stdout** (normalization makes it exempt — the regression S-HIGH3 guards against).
9. **relative code path** — guard: soft, Step `none`, `file_path: "./src/b.ts"` → stdout has `additionalContext`.
10. **subdir cwd** — `CLAUDE_PROJECT_DIR=$fixture` but stdin `.cwd=$fixture/src`, guard: soft, Step `none`,
    Write `src/a.js` → stdout has `additionalContext` (root still resolves via CLAUDE_PROJECT_DIR, not .cwd).
11. **`.minions-root` present** — a `.minions-root` with `path: state` redirecting root to `$fixture/state`
    (with config.yml guard:soft + STATE Step none there) → code edit nudges (the non-default-root branch works).
12. **`.minions-root` disabled** — file says `disabled` → **empty stdout** (DISABLED branch).
13. **path with spaces** — `file_path: "$pd/src/my file.js"`, guard: soft, Step `none` → `additionalContext`
    (quoting regression).
14. **malformed stdin** — pipe `not json` with jq present → **empty stdout, exit 0** (fail-safe).
15. **jq absent** — run with a `PATH` that has real coreutils but **no `jq`** (prepend a tmp bin dir and
    shadow only jq; do NOT use empty `PATH=` which also hides `cat`/`grep`), guard: hard, code edit →
    **empty stdout, exit 0** (fail-safe; hard must not block on a broken hook).
Also assert in case 4/15 that exit code is 0. Exempt-class coverage: cases 6,7,8 cover root/md; add a
`*/node_modules/*` and a `*.lock` mini-assert if cheap. Print `PASS`/`FAIL` per case + a final tally;
exit nonzero if any fail.

- [ ] **Step 4: Validate**

```bash
chmod +x scripts/guard.sh scripts/minions-hook-lib.sh scripts/test-guard.sh
bash -n scripts/minions-hook-lib.sh && bash -n scripts/guard.sh   # syntax OK
bash scripts/test-guard.sh                                         # ALL cases PASS
test -x scripts/guard.sh && echo "guard.sh executable"
grep -q 'exit 0' scripts/guard.sh && ! grep -q 'set -e' scripts/guard.sh   # fail-safe shape, no set -e
[ "$(grep -vE '^\s*(#|$)' scripts/guard.sh | tail -1)" = "exit 0" ]        # last real line is exit 0
grep -q 'additionalContext' scripts/guard.sh && grep -q 'permissionDecision' scripts/guard.sh
! grep -qE '\\s|grep -P' scripts/guard.sh scripts/minions-hook-lib.sh      # POSIX portability (no \s, no grep -P)
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
4. **Reminder condition** (built-but-not-reconciled; uses Step AND Status):
   `status=$(mh_state_status "$root")`; then
   ```
   case "$step" in
     qa|verify|review) : ;;                                  # past code, reconcile not reached
     code) case "$status" in *done*) : ;; *) exit 0 ;; esac ;;  # code DONE only (not mid-build)
     *) exit 0 ;;                                             # none/reconcile/curate/… → silent
   esac
   ```
   (Broadened from `{verify,review}` per review: `code`-done is the most common walk-away point; `qa`
   is included for enum-completeness though the qa step is dropped.)
5. Emit (NON-blocking — doc-confirmed shape): `out=$(jq -n '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:"This feature is built but not reconciled — run /minions:reconcile (then /minions:curate) to fold SPEC/ARCH to what shipped and update project knowledge before moving on."}}') && printf '%s' "$out"; exit 0`.
   - **NEVER** emit `{"decision":"block"}` and **never** exit 2 (both prevent stopping). The
     `Stop`+`additionalContext` non-blocking shape is doc-confirmed (https://code.claude.com/docs/en/hooks.md
     — "non-error feedback that continues the conversation"); Task 4 UAT still confirms it surfaces live.
   - The script's final line is an unconditional `exit 0`.

- [ ] **Step 2: Write `scripts/test-reconcile-reminder.sh`**

Same fixture pattern. Cases:
1. Step `review` → stdout has `additionalContext` mentioning `/minions:reconcile`; assert **no**
   `"decision"` and no `"block"` substring (non-blocking guarantee).
2. Step `verify` → reminder present.
3. Step `code`, Status `done` → reminder present (code-done is past-code).
4. Step `code`, Status `in progress` → **empty stdout** (still building; not past code).
5. Step `none` → **empty stdout**.
6. Step `curate` → **empty stdout** (reconcile already past).
7. uninitialized repo → **empty stdout**.
8. malformed stdin (non-JSON, jq present) → **empty stdout, exit 0** (fail-safe).
9. `.minions-root` `disabled` → **empty stdout** (DISABLED branch).
10. jq absent (jq-specific stub, real coreutils present) → **empty stdout, exit 0** (fail-safe).
Every case also asserts exit 0 and no `"decision"`/`"block"` substring. Print PASS/FAIL + tally;
nonzero exit on any failure.

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
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh\"" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-reminder.sh\"" }
        ]
      }
    ]
  }
}
```
Two deliberate refinements over the design's literal `Edit|Write` wording (per plan review):
- **`MultiEdit` added** to the matcher — it carries `.tool_input.file_path` like Edit/Write and is the
  tool Claude most often uses for multi-hunk source edits; omitting it would let a large fraction of
  real code edits **bypass `hard` mode**. `NotebookEdit` stays deferred (named, not accidental).
- **Invoke via `bash "<path>"`** rather than executing the script directly — removes the dependency on
  the committed `+x` bit surviving a fresh clone (a lost mode bit would silently disable the hook).
(For a feature-spine edit the coder runs *inside* a workflow, so Step≠none keeps the guard silent
regardless of matcher.)

- [ ] **Step 2: Confirm discovery + JSON validity; decide on plugin.json**

```bash
jq . hooks/hooks.json >/dev/null && echo "hooks.json valid JSON"
jq -e '.hooks.PreToolUse[0].matcher == "Edit|MultiEdit|Write"' hooks/hooks.json
jq -e '.hooks.PreToolUse[0].hooks[0].command | test("bash .*guard.sh")' hooks/hooks.json
jq -e '.hooks.Stop[0].hooks[0].command | test("bash .*reconcile-reminder.sh")' hooks/hooks.json
jq -e '.hooks.Stop[0] | has("matcher") | not' hooks/hooks.json   # Stop takes no tool matcher
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
  heuristic right (any false nags on `*.json`/`*.yml` **config files** — they're intentionally not
  exempt)? Did the Stop reminder over-fire? **Did `hard` actually block a `MultiEdit`** (the matcher now
  includes it — confirm it isn't bypassed)? Did the soft `additionalContext` message actually surface in
  the conversation (doc says yes; confirm live)?

- [ ] **Step 5: Note results + push.** Append an "Increment 4 UAT results" section to this file, then:
```bash
git add docs/plans/2026-06-30-minions-v2-inc4-guard-hooks.md
git commit -m "Record increment 4 UAT results"
git push origin main   # batched push of the whole increment
```

---

## Plan review (2026-06-30, pre-execution)

Two independent internal reviewers (design-fidelity lens; shell/hook-correctness lens) — both
**SHIP-WITH-FIXES**. (codex still unavailable — expired token; re-run after `codex login` if you want
the external angle.) The shell reviewer's one HIGH — "PreToolUse may ignore `additionalContext`, making
soft mode a silent no-op" — **conflicted with the first hook-mechanics research**, so I resolved it
against the authoritative doc (WebFetch of https://code.claude.com/docs/en/hooks.md): PreToolUse
**does** support `additionalContext` (omit `permissionDecision` → tool proceeds, message delivered), and
Stop supports it for non-blocking feedback. Soft mode stands. The doc also confirmed the fail-safe:
only exit 2 blocks; any other nonzero is non-blocking, so no crash can block an edit even in `hard`.

Fixes applied to the plan from the valid findings:
- **HIGH — reconcile-reminder broadened** from `{verify,review}` to `qa|verify|review` + `code`-done
  (via a new `mh_state_status`) — `code`-done is the most common walk-away point. (Task 2)
- **HIGH — exempt-matching construct pinned** to a bash `case`/glob with the exact patterns + a test
  per exempt class (was unspecified — the most safety-sensitive branch). (Task 1)
- **HIGH — relative `file_path` normalized** against the project dir before matching (else a relative
  `docs/minions/*` edit is misclassified as code and *blocked* in hard mode). (Task 1, Global Constraints)
- **MEDIUM — root resolution hardened:** prefer `$CLAUDE_PROJECT_DIR` over `.cwd` (subdir trap);
  absolute `.minions-root` `path:` handled; quote/comment/CR trimming specified. (Task 1, Global Constraints)
- **MEDIUM — fail-safe tightened:** capture jq output + unconditional trailing `exit 0`; added tests for
  malformed stdin, paths-with-spaces, `.minions-root` present, `DISABLED`, subdir cwd; jq-absent test now
  uses a jq-specific stub (not empty `PATH=`). (Tasks 1–2)
- **LOW→adopted — `MultiEdit` added to the matcher** (else most multi-hunk code edits bypass `hard`);
  hooks invoked via `bash "<path>"` (no dependency on the committed `+x` bit); Stop-omits-matcher
  asserted; POSIX-only portability (`[[:space:]]`, no `\s`/`grep -P`) and `${VAR:-default}` under
  `set -u` made explicit. (Tasks 1, 3, Global Constraints)
- **Status parse + documented edge:** guard keys on Step≠none and `curate` resets Step→`none` on ship
  (verified inc3c); an abandoned feature at a done step is a named, accepted edge.

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
