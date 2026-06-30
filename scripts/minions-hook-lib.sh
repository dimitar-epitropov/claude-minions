#!/usr/bin/env bash
# minions-hook-lib.sh — sourced helper for minions Claude Code hooks.
# Pure functions only; no side effects on source.
# Every function fails safe: missing/bad input → benign default.
# POSIX-portable: uses [[:space:]] and bash param-expansion trimming only.

# mh_have_jq — returns 0 if jq is present on PATH.
mh_have_jq() { command -v jq >/dev/null 2>&1; }

# mh_project_dir <stdin-json>
# Echoes the project root dir. Preference order (per Global Constraints):
#   1. $CLAUDE_PROJECT_DIR  (platform-guaranteed repo root — never a subdir)
#   2. .cwd from stdin JSON (fallback via jq)
#   3. $PWD                 (last resort)
mh_project_dir() {
    local json="${1:-}"
    local cpd="${CLAUDE_PROJECT_DIR:-}"
    if [ -n "$cpd" ]; then
        printf '%s' "$cpd"
        return
    fi
    # Try .cwd from JSON if jq is available
    if mh_have_jq && [ -n "$json" ]; then
        local cwd
        cwd=$(printf '%s' "$json" | jq -r '.cwd // empty' 2>/dev/null)
        if [ -n "$cwd" ]; then
            printf '%s' "$cwd"
            return
        fi
    fi
    # Fall back to PWD — never empty under bash
    printf '%s' "${PWD:-/}"
}

# mh_resolve_root <project_dir>
# Echoes the resolved <root> absolute path, the literal "DISABLED", or empty (uninitialized).
# Reads $pd/.minions-root if present; otherwise defaults to $pd/docs/minions.
# Never uses jq (file is YAML-ish, not JSON).
mh_resolve_root() {
    local pd="${1:-}"
    [ -z "$pd" ] && { printf ''; return; }

    if [ -f "$pd/.minions-root" ]; then
        # Extract the 'path:' line (POSIX grep -E, no GNU extensions)
        local raw_line
        raw_line=$(grep -E '^path:' "$pd/.minions-root" 2>/dev/null | head -1)
        if [ -n "$raw_line" ]; then
            # Strip 'path:' prefix
            local val="${raw_line#path:}"
            # Trim leading/trailing whitespace via bash param expansion (POSIX [[:space:]])
            while [ "${val#[[:space:]]}" != "$val" ]; do val="${val#[[:space:]]}"; done
            while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done
            # Strip surrounding quotes (single or double)
            val="${val#\'}"  ; val="${val%\'}"
            val="${val#\"}"  ; val="${val%\"}"
            # Strip inline comment (everything from ' #' onward)
            val="${val%%#*}"
            # Strip CR (Windows line endings)
            val="${val%$'\r'}"
            # Final whitespace trim after stripping
            while [ "${val#[[:space:]]}" != "$val" ]; do val="${val#[[:space:]]}"; done
            while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done

            if [ -z "$val" ] || [ "$val" = "disabled" ]; then
                printf 'DISABLED'
                return
            fi
            # Absolute path → use as-is; relative → prefix project dir
            case "$val" in
                /*) printf '%s' "$val" ;;
                *)  printf '%s' "$pd/$val" ;;
            esac
            return
        fi
        # .minions-root exists but no 'path:' line — treat as disabled
        printf 'DISABLED'
        return
    fi

    # No .minions-root: default to docs/minions if it exists
    if [ -d "$pd/docs/minions" ]; then
        printf '%s' "$pd/docs/minions"
    else
        printf ''  # uninitialized
    fi
}

# mh_config_guard <root>
# Echoes off|soft|hard from $root/config.yml. Default: soft.
mh_config_guard() {
    local root="${1:-}"
    [ -z "$root" ] && { printf 'soft'; return; }
    local line
    line=$(grep -E '^guard:' "$root/config.yml" 2>/dev/null | head -1)
    if [ -n "$line" ]; then
        local val="${line#guard:}"
        # Trim whitespace
        while [ "${val#[[:space:]]}" != "$val" ]; do val="${val#[[:space:]]}"; done
        while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done
        # Strip inline comment
        val="${val%%#*}"
        while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done
        case "$val" in
            off|soft|hard) printf '%s' "$val" ;;
            *) printf 'soft' ;;  # unrecognized → default soft
        esac
    else
        printf 'soft'  # absent/unreadable → default soft
    fi
}

# mh_state_step <root>
# Echoes the Step value from $root/STATE.md (lowercased). Default: none.
mh_state_step() {
    local root="${1:-}"
    [ -z "$root" ] && { printf 'none'; return; }
    local line
    line=$(grep -E '^[[:space:]]*-?[[:space:]]*\*\*Step:\*\*' "$root/STATE.md" 2>/dev/null | head -1)
    if [ -n "$line" ]; then
        local val="${line##*\*\*Step:\*\*}"
        # Strip markdown bold markers, brackets, whitespace
        val="${val//\*\*/}"
        val="${val//[/}"
        val="${val//]/}"
        # Trim whitespace
        while [ "${val#[[:space:]]}" != "$val" ]; do val="${val#[[:space:]]}"; done
        while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done
        # Lowercase via tr
        val=$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')
        printf '%s' "${val:-none}"
    else
        printf 'none'
    fi
}

# mh_state_status <root>
# Echoes the Status value from $root/STATE.md (lowercased). Default: empty.
# Used by reconcile-reminder to tell code-in-progress from code-done.
mh_state_status() {
    local root="${1:-}"
    [ -z "$root" ] && { printf ''; return; }
    local line
    line=$(grep -E '^[[:space:]]*-?[[:space:]]*\*\*Status:\*\*' "$root/STATE.md" 2>/dev/null | head -1)
    if [ -n "$line" ]; then
        local val="${line##*\*\*Status:\*\*}"
        val="${val//\*\*/}"
        # Trim whitespace
        while [ "${val#[[:space:]]}" != "$val" ]; do val="${val#[[:space:]]}"; done
        while [ "${val%[[:space:]]}" != "$val" ]; do val="${val%[[:space:]]}"; done
        # Lowercase
        val=$(printf '%s' "$val" | tr '[:upper:]' '[:lower:]')
        printf '%s' "$val"
    else
        printf ''
    fi
}
