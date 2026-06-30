#!/usr/bin/env bash
# guard.sh — PreToolUse hook: nudges/denies code edits outside a minions workflow.
# Fail-safe: any error, missing jq, bad JSON, unexpected path → exit 0 silent.
# set -u only (errexit is NOT used — we control every exit path explicitly).
set -u

# Source the shared hook library; if that fails, exit 0 (fail-safe).
. "$(dirname "$0")/minions-hook-lib.sh" || exit 0

# 1. Read stdin.
input=$(cat)

# 2. jq gate — no jq means we cannot parse JSON safely; fail safe.
mh_have_jq || exit 0

# 3. Resolve project dir and minions root.
pd=$(mh_project_dir "$input")
root=$(mh_resolve_root "$pd")

# 4. DISABLED or uninitialized repo → silent.
[ "$root" = "DISABLED" ] && exit 0
[ -z "$root" ] && exit 0

# 5. No config.yml → not really initialized → silent.
[ -f "$root/config.yml" ] || exit 0

# 6. Guard mode check.
guard=$(mh_config_guard "$root")
[ "$guard" = "off" ] && exit 0

# 7. Extract file_path from stdin JSON; normalize to absolute path.
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$fp" ] && exit 0

# Normalize: strip leading ./
case "$fp" in
    ./*) fp="${fp#./}" ;;
esac
# If not absolute, prefix with project dir
case "$fp" in
    /*) ;;
    *)  fp="$pd/$fp" ;;
esac

# 8. Code-vs-exempt classification via bash case/glob (NOT regex, NOT external grep).
# Heuristic errs toward exempting — silence beats nagging.
# Matching on normalized absolute path.
case "$fp" in
    # Under the resolved minions root (framework-managed files)
    "$root"/*)
        exit 0 ;;
    # Any docs/minions path (belt-and-suspenders for non-default roots)
    */docs/minions/*)
        exit 0 ;;
    # Documentation files
    *.md|*.markdown|*.txt)
        exit 0 ;;
    # CLAUDE config files
    */CLAUDE.md|*/CLAUDE.local.md)
        exit 0 ;;
    # Lock/generated files
    */package-lock.json|*/yarn.lock|*.lock)
        exit 0 ;;
    # Scratch/transient segments
    */scratch/*|*/tmp/*|*/.git/*|*/node_modules/*|*/dist/*|*/build/*)
        exit 0 ;;
    # The .minions-root marker file itself
    */.minions-root)
        exit 0 ;;
    # Everything else is treated as code — fall through to active-workflow check.
esac

# 9. Active-workflow check: if a workflow is in flight, it owns these edits.
step=$(mh_state_step "$root")
[ "$step" != "none" ] && exit 0

# 10. No active workflow + code edit → act per guard mode.
MSG="No active minions workflow. For code changes, use /minions:quick (small) or /minions:feature (larger) so the work is specced, planned, and reconciled."

case "$guard" in
    soft)
        out=$(jq -n --arg m "$MSG" \
            '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}') \
            && printf '%s' "$out"
        ;;
    hard)
        out=$(jq -n --arg m "$MSG (guard: hard — set guard: soft|off in $root/config.yml to relax)" \
            '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}') \
            && printf '%s' "$out"
        ;;
esac

exit 0
