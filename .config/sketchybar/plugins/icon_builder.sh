#!/bin/bash
source "$CONFIG_DIR/plugins/icon_map_fn.sh"

# Query a single workspace's windows and return its icon string.
# Only used for one-off lookups; the batch version below is preferred.
get_workspace_icons() {
  local ws="$1"
  local icons=""
  local count=0
  while IFS= read -r app; do
    [ -z "$app" ] && continue
    icon_map "$app"
    # Deduplicate icons, cap at 5
    if [[ "$icons" != *"$icon_result"* ]] && [ "$count" -lt 5 ]; then
      [ -n "$icons" ] && icons+=" "
      icons+="$icon_result"
      count=$((count + 1))
    fi
  done <<< "$(aerospace list-windows --workspace "$ws" --format '%{app-name}')"
  echo "$icons"
}

# Build icon strings for ALL workspaces in one pass from pre-fetched window data.
# Input: output of `aerospace list-windows --all --format '%{workspace}|%{app-name}'`
# Sets globals: WS_ICONS_<ws>, WS_HAS_WINDOWS_<ws>, WS_ICON_COUNT_<ws>, HAS_WINDOWS_LIST
# Uses printf -v for dynamic variable assignment (no eval, no subprocess).
build_all_workspace_icons() {
  local all_windows="$1"
  HAS_WINDOWS_LIST=""

  while IFS='|' read -r ws app; do
    [ -z "$ws" ] && continue
    icon_map "$app"

    # Read current state for this workspace
    local var_icons="WS_ICONS_${ws}"
    local var_count="WS_ICON_COUNT_${ws}"
    local var_has="WS_HAS_WINDOWS_${ws}"
    local current_icons="${!var_icons}"
    local current_count="${!var_count:-0}"

    # Mark workspace as having windows (track once)
    if [ -z "${!var_has}" ]; then
      printf -v "WS_HAS_WINDOWS_${ws}" "1"
      HAS_WINDOWS_LIST+="${ws}"$'\n'
    fi

    # Deduplicate and cap at 5 icons
    if [[ "$current_icons" != *"$icon_result"* ]] && [ "$current_count" -lt 5 ]; then
      local sep=""
      [ -n "$current_icons" ] && sep=" "
      printf -v "WS_ICONS_${ws}" "%s%s%s" "$current_icons" "$sep" "$icon_result"
      printf -v "WS_ICON_COUNT_${ws}" "%d" "$(( current_count + 1 ))"
    fi
  done <<< "$all_windows"
}
