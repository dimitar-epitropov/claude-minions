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
#
#    STATE format is non-deterministic: agents MAY write "done" folded into
#    the Step value ("code done", "verify done") OR as a bare Step with a
#    Status line that contains "done".  We must handle both forms robustly:
#
#      folded:  **Step:** code done    → step="code done", status=""
#      split:   **Step:** code         → step="code",      status="all tasks committed and done"
#      review:  **Step:** review       → step="review",    status="review clean"  (no "done" anywhere)
#
#    Derive a base token (first word of step) and a done_flag that is set
#    when "done" appears in EITHER the step value OR the status.
base=${step%% *}
case "$step $status" in *done*) done_flag=1 ;; *) done_flag=0 ;; esac

#    Fire for:
#      qa|verify|review — these steps run after code; reconcile not reached yet.
#        Fire regardless of done_flag (review writes "review clean", not "done").
#      code — fire only when done_flag is set (not mid-build).
#    Stay silent for: none, specify, architect, plan, reconcile, curate, and any
#      code step that has not yet been marked done.
case "$base" in
    qa|verify|review) : ;;
    code) [ "$done_flag" = 1 ] || exit 0 ;;
    *) exit 0 ;;
esac

# 8. Emit non-blocking Stop additionalContext reminder — must stay non-blocking; see Global Constraints.
#    Capture jq output before printing so a jq failure cannot leak a nonzero exit.
out=$(jq -n '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:"This feature is built but not reconciled — run /minions:reconcile (then /minions:curate) to fold SPEC/ARCH to what shipped and update project knowledge before moving on."}}') && printf '%s' "$out"

exit 0
