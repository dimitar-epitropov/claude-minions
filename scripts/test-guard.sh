#!/usr/bin/env bash
# test-guard.sh — harness for guard.sh; crafted stdin JSON → asserted stdout/exit.
# Each case creates a temp fixture dir, writes docs/minions/config.yml + STATE.md as needed,
# pipes crafted stdin JSON to guard.sh with CLAUDE_PROJECT_DIR=$fixture, asserts results.
# Prints PASS/FAIL per case; exits nonzero if any fail.

set -u

GUARD="$(dirname "$0")/guard.sh"
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

# Helper: setup standard docs/minions with given guard value and step
# Usage: setup_minions <fixture> <guard_val> <step_val>
setup_minions() {
    local d="$1" g="$2" s="$3"
    mkdir -p "$d/docs/minions"
    printf 'guard: %s\n' "$g" > "$d/docs/minions/config.yml"
    printf '## Now\n- **Step:** %s\n- **Status:** \n' "$s" > "$d/docs/minions/STATE.md"
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
        printf 'PASS  case %4s: %s\n' "$num" "$desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf 'FAIL  case %4s: %s\n' "$num" "$desc"
        printf '      exit=%d  stdout=%s\n' "$ec" "${stdout:-(empty)}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── Case 1: uninitialized repo (no docs/minions) ──────────────────────────────
f=$(make_fixture)
# No docs/minions created
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 1 "uninitialized repo → empty stdout, exit 0" "$out" "$ec" "empty"

# ── Case 2: guard: off ────────────────────────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "off" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 2 "guard: off, code edit → empty stdout" "$out" "$ec" "empty"

# ── Case 3: guard: soft, Step none, code edit → additionalContext ─────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 3 "guard: soft, Step none, code edit → has additionalContext" "$out" "$ec" "has" "additionalContext"
# Also assert no permissionDecision
lacks_out="$out"
case "$lacks_out" in
    *"permissionDecision"*)
        printf 'FAIL  case 3b: soft mode must not have permissionDecision\n'
        FAIL_COUNT=$((FAIL_COUNT + 1))
        ;;
    *)
        printf 'PASS  case 3b: soft mode has no permissionDecision\n'
        PASS_COUNT=$((PASS_COUNT + 1))
        ;;
esac

# ── Case 4: guard: hard, Step none, code edit → deny ─────────────────────────
f=$(make_fixture)
setup_minions "$f" "hard" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 4 "guard: hard, Step none → permissionDecision:deny (exit 0)" "$out" "$ec" "has" "permissionDecision"
# Also assert it contains "deny"
case "$out" in
    *"deny"*) printf 'PASS  case 4b: hard mode output contains deny\n'; PASS_COUNT=$((PASS_COUNT + 1)) ;;
    *)        printf 'FAIL  case 4b: hard mode output missing deny\n';  FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
esac

# ── Case 5: subagent edit (agent_id present), guard soft → empty stdout ───────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f","agent_id":"sub-123","agent_type":"minions:coder"}
EOF
)
ec=$?
assert_case 5 "subagent edit (agent_id present), guard soft → empty stdout (governed)" "$out" "$ec" "empty"

# ── Case 5b: subagent edit, guard hard → empty stdout (never blocked) ─────────
f=$(make_fixture)
setup_minions "$f" "hard" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f","agent_id":"sub-123","agent_type":"minions:coder"}
EOF
)
ec=$?
assert_case "5b" "subagent edit, guard hard → empty stdout (subagent never blocked)" "$out" "$ec" "empty"

# ── Case 5c: main-session edit, Step code (mid-feature), soft → nudges ────────
# The corrected behavior: freehand edit mid-feature (no agent_id) IS nudged.
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf 'guard: soft\n' > "$f/docs/minions/config.yml"
printf '## Now\n- **Step:** code\n- **Status:** building\n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case "5c" "main-session edit, Step code, no agent_id, soft → additionalContext (nudge)" "$out" "$ec" "has" "additionalContext"

# ── Case 5d: main-session edit, Step none, soft → additionalContext ───────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case "5d" "main-session edit, Step none, no agent_id, soft → additionalContext" "$out" "$ec" "has" "additionalContext"

# ── Case 6: framework file (absolute path to docs/minions/STATE.md) ──────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/docs/minions/STATE.md"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 6 "framework file (absolute docs/minions path) → empty stdout" "$out" "$ec" "empty"

# ── Case 7: markdown file → empty stdout ─────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/README.md"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 7 "markdown file (README.md) → empty stdout" "$out" "$ec" "empty"

# ── Case 8: relative path to docs/minions/config.yml → empty stdout ──────────
# (Regression S-HIGH3: normalization must classify this as framework file)
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/minions/config.yml"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 8 "relative docs/minions path → empty stdout (normalization regression)" "$out" "$ec" "empty"

# ── Case 9: relative code path (./src/b.ts) → additionalContext ──────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"./src/b.ts"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 9 "relative code path ./src/b.ts → has additionalContext" "$out" "$ec" "has" "additionalContext"

# ── Case 10: subdir cwd — CLAUDE_PROJECT_DIR=$fixture, .cwd=$fixture/src ─────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
mkdir -p "$f/src"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f/src"}
EOF
)
ec=$?
assert_case 10 "subdir cwd, CLAUDE_PROJECT_DIR=fixture → still nudges (uses env var)" "$out" "$ec" "has" "additionalContext"

# ── Case 11: .minions-root redirecting root to $fixture/state ────────────────
f=$(make_fixture)
mkdir -p "$f/state"
printf 'path: state\n' > "$f/.minions-root"
printf 'guard: soft\n' > "$f/state/config.yml"
printf '## Now
- **Step:** none
- **Status:** 
' > "$f/state/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 11 ".minions-root redirects root → code edit nudges" "$out" "$ec" "has" "additionalContext"

# ── Case 12: .minions-root disabled → empty stdout ───────────────────────────
f=$(make_fixture)
printf 'disabled\n' > "$f/.minions-root"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 12 ".minions-root disabled → empty stdout" "$out" "$ec" "empty"

# ── Case 13: path with spaces ─────────────────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/my file.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 13 "path with spaces → has additionalContext (quoting regression)" "$out" "$ec" "has" "additionalContext"

# ── Case 14: malformed stdin → empty stdout, exit 0 (fail-safe) ──────────────
f=$(make_fixture)
setup_minions "$f" "hard" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<'EOF'
not json
EOF
)
ec=$?
assert_case 14 "malformed stdin → empty stdout, exit 0 (fail-safe)" "$out" "$ec" "empty"

# ── Case 15: jq absent — shadow real jq with a broken executable stub ────────
# Brief: "prepend a tmp bin dir and shadow only jq; do NOT use empty PATH=".
# A broken jq stub means command -v jq finds the stub (mh_have_jq succeeds) BUT
# the stub exits non-zero so every jq call in guard.sh fails → fp="" → exit 0.
f=$(make_fixture)
setup_minions "$f" "hard" "none"
nojq_dir=$(mktemp -d)
FIXTURES+=("$nojq_dir")
# Create an executable jq stub that exits 1 (simulates broken/absent jq)
printf '#!/bin/sh\nexit 1\n' > "$nojq_dir/jq"
chmod +x "$nojq_dir/jq"
out=$(PATH="$nojq_dir:$PATH" CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 15 "jq absent/broken (stub PATH) → empty stdout, exit 0 (fail-safe)" "$out" "$ec" "empty"

# ── Bonus: node_modules exempt ───────────────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/node_modules/lodash/index.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 16 "node_modules path → empty stdout (exempt)" "$out" "$ec" "empty"

# ── Bonus: .lock file exempt ──────────────────────────────────────────────────
f=$(make_fixture)
setup_minions "$f" "soft" "none"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/package.lock"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 17 "*.lock file → empty stdout (exempt)" "$out" "$ec" "empty"

# ── Case 18: origin check — bulleted Step code, no agent_id → NUDGES ─────────
# Step is no longer the silence gate; only agent_id controls silence.
# Main-session edit mid-feature (no agent_id) must be nudged regardless of Step.
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf 'guard: soft\n' > "$f/docs/minions/config.yml"
printf '## Now\n- **Step:** code\n- **Status:** building\n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 18 "origin check: bulleted '- **Step:** code', no agent_id → additionalContext (nudge)" "$out" "$ec" "has" "additionalContext"

# ── Case 19: C1 regression — bulleted Step none (- **Step:** none) → nudges ──
# This case FAILS against the old col-0 grep (step parsed as none by default, but the
# new grep should parse it correctly and also return none — guard must nudge).
f=$(make_fixture)
mkdir -p "$f/docs/minions"
printf 'guard: soft\n' > "$f/docs/minions/config.yml"
printf '## Now\n- **Step:** none\n- **Status:** \n' > "$f/docs/minions/STATE.md"
out=$(CLAUDE_PROJECT_DIR="$f" bash "$GUARD" <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$f/src/a.js"},"cwd":"$f"}
EOF
)
ec=$?
assert_case 19 "C1 regression: bulleted '- **Step:** none' → has additionalContext (nudges)" "$out" "$ec" "has" "additionalContext"

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
