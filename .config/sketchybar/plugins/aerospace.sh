#!/bin/bash

# Event handler for workspace changes and app switches.
# Sourced files are eliminated in the compiled version (aerospace_compiled.sh).
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_builder.sh"

if [ "$SENDER" = "system_woke" ]; then
  # Refresh cached workspace list (may have changed while locked/asleep)
  aerospace list-workspaces --monitor all > /tmp/sketchybar_workspaces
fi

if [ "$SENDER" = "aerospace_workspace_change" ] || [ "$SENDER" = "front_app_switched" ] || [ "$SENDER" = "space_windows_change" ] || [ "$SENDER" = "system_woke" ]; then
  # Visible workspaces query runs in background while we fetch windows
  exec 3< <(aerospace list-workspaces --monitor all --visible)
  ALL_WINDOWS=$(aerospace list-windows --all --format '%{workspace}|%{app-name}')
  # read -d '' slurps all lines; returns 1 at EOF, so || true
  read -r -d '' VISIBLE <&3 || true
  exec 3<&-
  # All workspaces cached by spaces.sh at startup (avoids an aerospace call)
  ALL=$(< /tmp/sketchybar_workspaces)

  # Sets WS_ICONS_<ws> and WS_HAS_WINDOWS_<ws> globals for each workspace
  build_all_workspace_icons "$ALL_WINDOWS"

  # Separate highlight/dehighlight for different animation curves
  HIGHLIGHT_ARGS=()
  DEHIGHLIGHT_ARGS=()
  while IFS= read -r ws; do
    [ -z "$ws" ] && continue

    # Indirect variable expansion to read per-workspace globals
    local_icons_var="WS_ICONS_${ws}"
    local_icons="${!local_icons_var}"
    has_windows_var="WS_HAS_WINDOWS_${ws}"

    # Hide label (app icons) if workspace is empty; widen icon padding to compensate
    if [ -n "$local_icons" ]; then
      label_drawing=on
      icon_pad_right=2
    else
      label_drawing=off
      icon_pad_right=8
    fi

    # Newline-wrapped pattern match avoids grep subprocess
    if [[ $'\n'"$VISIBLE"$'\n' == *$'\n'"$ws"$'\n'* ]]; then
      # Visible workspace: white bg, dark text
      HIGHLIGHT_ARGS+=(--set "space.$ws" background.color=$SELECTED_BG_COLOR icon.color=$SELECTED_TEXT_COLOR label.color=$SELECTED_TEXT_COLOR label="$local_icons" label.drawing=$label_drawing icon.padding_right=$icon_pad_right)
    elif [ -z "${!has_windows_var}" ]; then
      # Empty workspace: dim text
      DEHIGHLIGHT_ARGS+=(--set "space.$ws" background.color=$UNFOCUSED_BG_COLOR icon.color=$EMPTY_TEXT_COLOR label.color=$EMPTY_TEXT_COLOR label="$local_icons" label.drawing=$label_drawing icon.padding_right=$icon_pad_right)
    else
      # Non-empty, not visible: bright text
      DEHIGHLIGHT_ARGS+=(--set "space.$ws" background.color=$UNFOCUSED_BG_COLOR icon.color=$WHITE label.color=$WHITE label="$local_icons" label.drawing=$label_drawing icon.padding_right=$icon_pad_right)
    fi
  done <<< "$ALL"

  # Single batched call: sin for snappy highlight, tanh for smooth dehighlight
  sketchybar --animate sin 5 "${HIGHLIGHT_ARGS[@]}" \
             --animate tanh 5 "${DEHIGHLIGHT_ARGS[@]}"
fi
