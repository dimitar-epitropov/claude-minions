#!/usr/bin/env bash
# test-reconcile-reminder.sh — harness for reconcile-reminder.sh; crafted stdin JSON → asserted stdout/exit.
# Each case creates a temp fixture dir, writes docs/minions/STATE.md as needed,
# pipes crafted stdin JSON to reconcile-reminder.sh with CLAUDE_PROJECT_DIR=$fixture, asserts results.
# Prints PASS/FAIL per case; exits nonzero if any fail.

set -u

SCRIPT="$(dirname "$0")/reconcile-reminder.sh"
PASS_COUNT=0
FAIL_COUNT=0
FIXTURES=()

# Helper: create a fresh fixture dir
make_fixture() {
    local d
    d=$(mktemp -d)
    FIXTURES+=("$d")
    printf '%s' "$d"
}

# Helper: setup docs/minions with given step and status
# Usage: setup_minions <fixture> <step_val> <status_val>
setup_minions() {
    local d="$1" s="$2" st="$3"
    mkdir -p "$d/docs/minions"
    printf '## Now\n- **Step:** %s\n- **Status:** %s\n' "$s" "$st" > "$d/docs/minions/STATE.md"
}

# Helper: assert case
# Usage: assert_case <case_num> <description> <stdout> <exit_code> <check_type> [check_value]
# check_type: "empty" | "has" | "lacks"
assert_case() {
    local num="$1" desc="$2" stdout="$3" ec="$4" check="$5" val="${6:-}"
    local ok=1

    # Always assert exit 0
    if [ "$ec" -ne 0 ]; then
        ok=0
    fi

    case "$check" in
        empty)
            [ -n "$stdout" ] && ok=0
            ;;
        has)
            case "$stdout" in
                *"$val"*) ;;
                *) ok=0 ;;
            esac
            ;;
        lacks)
            case "$stdout" in
                *"$val"*) ok=0 ;;
            esac
            ;;
    esac

    if [ "$ok" -eq 1 ]; then
        printf 'PASS  case %3s: %s\n' "$num" "$desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf 'FAIL  case %3s: %s\n' "$num" "$desc"
        printf '      exit=%d  stdout=%s\n' "$ec" "${stdout:-(empty)}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Helper: assert non-blocking guarantee (no "decision" or "block" in output)
# Usage: assert_nonblocking <case_label> <stdout>
assert_nonblocking() {
    local label="$1" stdout="$2"
    local ok=1
    case "$stdout" in
        *'"decision"'*) ok=0 ;;
    esac
    case "$stdout" in
        *'"block"'*) ok=0 ;;
    esac
    # Also check for the literal word block outside quotes
    case "$stdout" in
        *'block'*) ok=0 ;;
    esac
    if [ "$ok" -eq 1 ]; then
        printf 'PASS  %s: no "decision"/"block" (non-blocking)\n' "$label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf 'FAIL  %s: found "decision" or "block" (MUST NOT block)\n' "$label"
        printf '      stdout=%s\n' "${stdout:-(empty)}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Canonical Stop hook stdin (the hook receives Stop event JSON)
stop_stdin() {
    local cwd="${1:-/tmp}"
    printf '{"hook_event_name":"Stop","cwd":"%s"}' "$cwd"
}

# ── Case 1: Step review → reminder present, non-blocking ─────────────────────
f=$(make_fixture)
setup_minions "$f" "review" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 1 "Step review → has additionalContext + /minions:reconcile" "$out" "$ec" "has" "additionalContext"
assert_case 1 "Step review → output mentions /minions:reconcile" "$out" "$ec" "has" "/minions:reconcile"
assert_nonblocking "case 1" "$out"

# ── Case 2: Step verify → reminder present ───────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "verify" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 2 "Step verify → has additionalContext" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 2" "$out"

# ── Case 3: Step "code done" (folded form — what coder.md actually writes) → reminder fires ──
# agents/coder.md writes: **Step:** code done  (no separate Status "done")
f=$(make_fixture)
setup_minions "$f" "code done" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 3 "Step 'code done' (folded form) → has additionalContext" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 3" "$out"

# ── Case 3b: Step "verify done" (folded form — what verifier.md actually writes) → reminder fires ──
# agents/verifier.md writes: **Step:** verify done
f=$(make_fixture)
setup_minions "$f" "verify done" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case "3b" "Step 'verify done' (folded form) → has additionalContext" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 3b" "$out"

# ── Case 3c: Step "review" + Status "review clean" (no "done") → reminder fires ──
# skills/review/SKILL.md writes: **Step:** review  **Status:** review clean
# review runs AFTER code so reconcile hasn't happened yet — fire regardless of done_flag.
f=$(make_fixture)
setup_minions "$f" "review" "review clean"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case "3c" "Step 'review' + Status 'review clean' (no done) → reminder fires" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 3c" "$out"

# ── Case 3d: Step "code" + Status "in progress" (split form, mid-build) → SILENT ──
# A split-form STATE where code is still running — must NOT fire the reminder.
f=$(make_fixture)
setup_minions "$f" "code" "in progress"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case "3d" "Step 'code' + Status 'in progress' (mid-build, split form) → empty stdout" "$out" "$ec" "empty"

# ── Case 3e: Step "code" + Status "all tasks committed and done" (split form with done in status) → fires ──
# An LLM may write done into the status rather than folding it into step.
f=$(make_fixture)
setup_minions "$f" "code" "all tasks committed and done"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case "3e" "Step 'code' + Status has 'done' (split form) → has additionalContext" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 3e" "$out"

# ── Case 4: Step code + Status "in progress" → empty stdout ──────────────────
f=$(make_fixture)
setup_minions "$f" "code" "in progress"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 4 "Step code, Status in progress → empty stdout (still building)" "$out" "$ec" "empty"

# ── Case 5: Step none → empty stdout ─────────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "none" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 5 "Step none → empty stdout" "$out" "$ec" "empty"

# ── Case 6: Step curate → empty stdout ───────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "curate" ""
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 6 "Step curate → empty stdout (reconcile already past)" "$out" "$ec" "empty"

# ── Case 7: uninitialized repo (no docs/minions) → empty stdout ──────────────
f=$(make_fixture)
# No docs/minions created
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 7 "uninitialized repo → empty stdout" "$out" "$ec" "empty"

# ── Case 8: malformed stdin (non-JSON, jq present) → exit 0, non-blocking ────
# When CLAUDE_PROJECT_DIR is unset and stdin is malformed, jq can't extract .cwd
# so mh_project_dir falls back to $PWD.  If the shell's $PWD happens to point at
# a live minions repo (e.g. this very repo during development), the reminder MAY
# still fire — that is acceptable.  What matters is that malformed stdin never
# causes a nonzero exit or a blocking "decision" response.
# Assert: exit 0 + no "decision"/"block" (non-blocking guarantee, not strict empty).
out=$(env -u CLAUDE_PROJECT_DIR bash "$SCRIPT" <<'EOF'
not json
EOF
)
ec=$?
assert_case 8 "malformed stdin, no CLAUDE_PROJECT_DIR → exit 0 (fail-safe, non-blocking)" "$out" "$ec" "lacks" '"decision"'
assert_nonblocking "case 8" "$out"

# ── Case 9: .minions-root disabled → empty stdout ────────────────────────────
f=$(make_fixture)
printf 'disabled\n' > "$f/.minions-root"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 9 ".minions-root disabled → empty stdout" "$out" "$ec" "empty"

# ── Case 10: jq absent (jq-specific stub exiting nonzero, real coreutils present) ──
# Prepend a tmp bin dir with a broken jq stub; real cat/grep/etc remain available.
# mh_have_jq finds the stub (command -v jq succeeds) but the stub exits 1 → fail-safe.
f=$(make_fixture)
setup_minions "$f" "review" ""
nojq_dir=$(mktemp -d)
FIXTURES+=("$nojq_dir")
printf '#!/bin/sh\nexit 1\n' > "$nojq_dir/jq"
chmod +x "$nojq_dir/jq"
out=$(PATH="$nojq_dir:$PATH" CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 10 "jq absent/broken (stub PATH) → empty stdout, exit 0 (fail-safe)" "$out" "$ec" "empty"

# ── Case 11: C1 regression — bulleted Step review (- **Step:** review) → FIRES ──
# This case FAILS against the old col-0 grep and PASSES after Fix 1.
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf '## Now\n- **Step:** review\n- **Status:** \n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 11 "C1 regression: bulleted '- **Step:** review' → has additionalContext (fires)" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 11" "$out"

# ── Case 12: C1 regression — bulleted Step code done → FIRES ─────────────────
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf '## Now\n- **Step:** code done\n- **Status:** \n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 12 "C1 regression: bulleted '- **Step:** code done' → has additionalContext (fires)" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 12" "$out"

# ── Case 13: C1 regression — bulleted Step none (- **Step:** none) → SILENT ──
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf '## Now\n- **Step:** none\n- **Status:** \n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 13 "C1 regression: bulleted '- **Step:** none' → empty stdout (silent)" "$out" "$ec" "empty"

# ── Cleanup ───────────────────────────────────────────────────────────────────
[ ${#FIXTURES[@]} -gt 0 ] && for d in "${FIXTURES[@]}"; do
    rm -rf "$d"
done

# ── Tally ─────────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf '\n%d/%d cases PASS\n' "$PASS_COUNT" "$TOTAL"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf '%d case(s) FAILED\n' "$FAIL_COUNT"
    exit 1
fi
exit 0
