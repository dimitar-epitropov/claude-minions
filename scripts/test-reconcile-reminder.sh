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
    printf '## Now\n**Step:** %s\n**Status:** %s\n' "$s" "$st" > "$d/docs/minions/STATE.md"
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
        printf 'PASS  case %2d: %s\n' "$num" "$desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf 'FAIL  case %2d: %s\n' "$num" "$desc"
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

# ── Case 3: Step code + Status done → reminder present ───────────────────────
f=$(make_fixture)
setup_minions "$f" "code" "done"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$SCRIPT" <<EOF
$(stop_stdin "$f")
EOF
)
ec=$?
assert_case 3 "Step code, Status done → has additionalContext" "$out" "$ec" "has" "additionalContext"
assert_nonblocking "case 3" "$out"

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

# ── Case 8: malformed stdin (non-JSON, jq present) → empty stdout, exit 0 ────
# When CLAUDE_PROJECT_DIR is unset and stdin is malformed, jq can't extract .cwd
# so mh_project_dir falls back to $PWD. With no docs/minions there, root is empty → exit 0.
# This tests the jq-parse fail-safe path end-to-end.
f=$(make_fixture)
# No docs/minions in cwd; use a temp dir as PWD that has no minions setup
out=$(env -u CLAUDE_PROJECT_DIR bash "$SCRIPT" <<'EOF'
not json
EOF
)
ec=$?
assert_case 8 "malformed stdin, no CLAUDE_PROJECT_DIR → empty stdout, exit 0 (fail-safe)" "$out" "$ec" "empty"

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

# ── Cleanup ───────────────────────────────────────────────────────────────────
for d in "${FIXTURES[@]}"; do
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
