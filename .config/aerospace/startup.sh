#!/bin/bash
set -uo pipefail

# AeroSpace launches this via launchd (non-login shell) — Homebrew is not on PATH there.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
# Set in ~/.zshrc, so absent here. `brew trust` data lives under it;
# without it brew looks in ~/.homebrew and rejects the sketchybar tap.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# All output (ours and every command's stdout/stderr) goes to the log.
# The previous run's log is kept alongside as startup.prev.txt.
logdir="$HOME/Library/Logs/aerospace"
logfile="$logdir/startup.txt"
mkdir -p "$logdir"
[ -f "$logfile" ] && mv "$logfile" "$logdir/startup.prev.txt"
exec >"$logfile" 2>&1

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Log an error, announce it, and mark the run as failed.
fail() {
    log "ERROR: $*"
    say "aerospace: $*"
    has_error=true
}

log "startup begin"
say "aerospace starting, please wait"

has_error=false
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Sketchybar: restart (starts it if not already running)
log "restarting sketchybar"
if ! brew services restart sketchybar; then
    fail "sketchybar failed to restart"
fi

get_window_ids() {
    aerospace list-windows --monitor all --app-bundle-id "$1" \
        | awk -F'|' '{print $1}' | tr -d ' ' | grep -v '^$'
}

# Wait for a new window (vs before snapshot), write its ID to outfile.
wait_for_window() {
    local bundle_id="$1"
    local before="$2"
    local outfile="$3"

    local i
    for i in $(seq 1 30); do
        sleep 1
        local after new_id
        after=$(get_window_ids "$bundle_id")
        new_id=$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -1)
        if [ -n "$new_id" ]; then
            log "$bundle_id: new window $new_id after ${i}s"
            echo "$new_id" > "$outfile"
            return 0
        fi
    done
    log "$bundle_id: no new window after 30s; current windows:"
    aerospace list-windows --monitor all --app-bundle-id "$bundle_id"
    return 1
}

# If app already running, use existing window. Otherwise launch and wait.
# Usage: ensure_window <bundle-id> <app-name> <outfile>
ensure_window() {
    local bundle_id="$1"
    local app_name="$2"
    local outfile="$3"

    local existing
    existing=$(get_window_ids "$bundle_id")

    if [ -n "$existing" ]; then
        log "$app_name: already running, using window $(echo "$existing" | head -1)"
        echo "$existing" | head -1 > "$outfile"
        return 0
    fi

    # Record launch failure for try_move to report (avoids overlapping `say`
    # calls from the parallel launches below).
    log "$app_name: launching"
    if ! open -a "$app_name"; then
        echo "$app_name" > "$outfile.launchfail"
        return 1
    fi

    wait_for_window "$bundle_id" "" "$outfile"
}

# Move a detected window to its workspace and set layout.
# Usage: try_move <name> <workspace> <layout>
try_move() {
    local name="$1" workspace="$2" layout="$3"

    if [ -f "$tmpdir/$name.launchfail" ]; then
        fail "$name failed to launch"
        return
    fi

    if [ ! -f "$tmpdir/$name" ]; then
        fail "$name timed out"
        return
    fi

    local window_id
    window_id=$(cat "$tmpdir/$name")
    log "$name: moving window $window_id to workspace $workspace ($layout)"

    if ! aerospace move-node-to-workspace "$workspace" --window-id "$window_id"; then
        fail "$name failed to move to workspace $workspace"
        return
    fi

    if ! aerospace workspace "$workspace"; then
        fail "$name failed to switch to workspace $workspace"
        return
    fi

    # `aerospace layout` exits 1 on a no-op (window already has that layout) and
    # prints nothing. Real failures print to stderr, so key off that, not $?.
    local layout_err
    layout_err=$(aerospace layout "$layout" --window-id "$window_id" 2>&1 >/dev/null)
    if [ -n "$layout_err" ]; then
        log "aerospace layout: $layout_err"
        fail "$name failed to set layout"
        return
    fi
}

# Ensure app windows exist (parallel — reuse existing or launch + wait)
ensure_window "com.googlecode.iterm2" "iTerm"   "$tmpdir/iterm"   &
ensure_window "org.mozilla.firefox"   "Firefox" "$tmpdir/firefox" &
wait

# Move windows to workspaces sequentially (avoids layout races)
try_move iterm   T h_tiles
try_move firefox W h_tiles

# iTerm second window — needs first window moved before snapshotting
before_iterm_second=$(get_window_ids "com.googlecode.iterm2")
log "iTerm: opening second window"
if ! osascript -e 'tell application "iTerm" to create window with default profile'; then
    log "iTerm: osascript failed to create window"
fi
wait_for_window "com.googlecode.iterm2" "$before_iterm_second" "$tmpdir/iterm2"
try_move iterm2 Y h_tiles

# Firefox second window — needs first window moved before snapshotting
before_firefox_second=$(get_window_ids "org.mozilla.firefox")
log "Firefox: opening second window"
/Applications/Firefox.app/Contents/MacOS/firefox --new-window 'about:blank' &
wait_for_window "org.mozilla.firefox" "$before_firefox_second" "$tmpdir/firefox2"
try_move firefox2 P h_tiles

if [ "$has_error" = true ]; then
    log "startup finished with errors"
    say "aerospace had an error"
else
    log "startup finished"
    say "aerospace finished"
fi
