#!/bin/bash
set -uo pipefail

# AeroSpace launches this via launchd (non-login shell) — Homebrew is not on PATH there.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
# Set in ~/.zshrc, so absent here. `brew trust` data lives under it;
# without it brew looks in ~/.homebrew and rejects the sketchybar tap.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

say "aerospace starting, please wait"

has_error=false
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Sketchybar: restart (starts it if not already running)
if ! brew services restart sketchybar; then
    say "aerospace: sketchybar failed to restart"
    has_error=true
fi

get_window_ids() {
    aerospace list-windows --monitor all --app-bundle-id "$1" 2>/dev/null \
        | awk -F'|' '{print $1}' | tr -d ' ' | grep -v '^$'
}

# Wait for a new window (vs before snapshot), write its ID to outfile.
wait_for_window() {
    local bundle_id="$1"
    local before="$2"
    local outfile="$3"

    for _ in $(seq 1 30); do
        sleep 1
        local after new_id
        after=$(get_window_ids "$bundle_id")
        new_id=$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -1)
        if [ -n "$new_id" ]; then
            echo "$new_id" > "$outfile"
            return 0
        fi
    done
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
        echo "$existing" | head -1 > "$outfile"
        return 0
    fi

    # Record launch failure for try_move to report (avoids overlapping `say`
    # calls from the parallel launches below).
    if ! open -a "$app_name" 2>/dev/null; then
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
        say "aerospace: $name failed to launch"
        has_error=true
        return
    fi

    if [ ! -f "$tmpdir/$name" ]; then
        say "aerospace: $name timed out"
        has_error=true
        return
    fi

    local window_id
    window_id=$(cat "$tmpdir/$name")

    if ! aerospace move-node-to-workspace "$workspace" --window-id "$window_id"; then
        say "aerospace: $name failed to move to workspace $workspace"
        has_error=true
        return
    fi

    if ! aerospace workspace "$workspace"; then
        say "aerospace: $name failed to switch to workspace $workspace"
        has_error=true
        return
    fi

    # `aerospace layout` exits 1 on a no-op (window already has that layout) and
    # prints nothing. Real failures print to stderr, so key off that, not $?.
    local layout_err
    layout_err=$(aerospace layout "$layout" --window-id "$window_id" 2>&1 >/dev/null)
    if [ -n "$layout_err" ]; then
        say "aerospace: $name failed to set layout"
        has_error=true
        return
    fi
}

# Ensure all app windows exist (parallel — reuse existing or launch + wait)
ensure_window "com.microsoft.Outlook"          "Microsoft Outlook" "$tmpdir/outlook" &
ensure_window "com.microsoft.teams2"           "Microsoft Teams"   "$tmpdir/teams"   &
ensure_window "com.googlecode.iterm2"          "iTerm"             "$tmpdir/iterm"   &
ensure_window "com.tinyspeck.slackmacgap"      "Slack"             "$tmpdir/slack"   &
ensure_window "org.mozilla.firefox"            "Firefox"           "$tmpdir/firefox" &
ensure_window "com.google.Chrome"              "Google Chrome"     "$tmpdir/chrome"  &
ensure_window "org.jkiss.dbeaver.core.product" "DBeaver"           "$tmpdir/dbeaver" &
wait

# Move windows to workspaces sequentially (avoids layout races)
try_move outlook C h_accordion
try_move teams   C h_accordion
try_move iterm   T h_tiles
try_move slack   S h_tiles
try_move firefox P h_tiles
try_move chrome  W h_tiles
try_move dbeaver D h_tiles

# iTerm second window — needs first window moved before snapshotting
before_iterm_second=$(get_window_ids "com.googlecode.iterm2")
osascript -e 'tell application "iTerm" to create window with default profile'
wait_for_window "com.googlecode.iterm2" "$before_iterm_second" "$tmpdir/iterm2"
try_move iterm2 Y h_tiles

if [ "$has_error" = true ]; then
    say "aerospace had an error"
else
    say "aerospace finished"
fi
