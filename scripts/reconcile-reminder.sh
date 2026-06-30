#!/usr/bin/env bash
# reconcile-reminder.sh — Stop hook: non-blocking reminder when a feature is built but not reconciled.
# Fail-safe: any error, missing jq, bad JSON, wrong step/status → exit 0 silent.
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

# 5. No STATE.md → workflow not active → silent.
[ -f "$root/STATE.md" ] || exit 0

# 6. Extract step and status from STATE.md.
step=$(mh_state_step "$root")
status=$(mh_state_status "$root")

# 7. Reminder condition: built-but-not-reconciled.
#    Fire for: qa|verify|review (past code, reconcile not reached)
#           or code + status contains "done" (code complete, not yet reconciled).
#    Stay silent for: none, reconcile, curate, or code still in progress.
case "$step" in
    qa|verify|review) : ;;
    code) case "$status" in *done*) : ;; *) exit 0 ;; esac ;;
    *) exit 0 ;;
esac

# 8. Emit non-blocking Stop additionalContext reminder — must stay non-blocking; see Global Constraints.
#    Capture jq output before printing so a jq failure cannot leak a nonzero exit.
out=$(jq -n '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:"This feature is built but not reconciled — run /minions:reconcile (then /minions:curate) to fold SPEC/ARCH to what shipped and update project knowledge before moving on."}}') && printf '%s' "$out"

exit 0
