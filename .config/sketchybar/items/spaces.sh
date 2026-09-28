#!/bin/bash

sketchybar --add event aerospace_workspace_change

# Map aerospace monitor ID → sketchybar display arrangement-id.
# aerospace's monitor-appkit-nsscreen-screens-id matches sketchybar's arrangement-id.
declare -A DISPLAY_MAP
while IFS='|' read -r aero_id nsscreen_id; do
  DISPLAY_MAP[$aero_id]=$nsscreen_id
done <<< "$(aerospace list-monitors --format '%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}')"

# Create a space.<id> item for each workspace, grouped by monitor/display.
ARGS=()
for aero_id in $(aerospace list-monitors | awk '{print $1}'); do
  display_id="${DISPLAY_MAP[$aero_id]:-$aero_id}"

  # Reorder workspaces so 0 appears after 9 but before letter workspaces.
  # (aerospace sorts alphanumerically, putting 0 before 1)
  for sid in $(aerospace list-workspaces --monitor "$aero_id" | awk '
    /^0$/ { has_zero=1; next }
    /^[A-Za-z]/ && !placed && has_zero { print "0"; placed=1 }
    { print }
    END { if (has_zero && !placed) print "0" }
  '); do
    ARGS+=(--add item space.$sid center                              \
           --set space.$sid icon="$sid"                              \
                            icon.align=center                        \
                            icon.padding_left=8                      \
                            icon.padding_right=8                     \
                            padding_left=5                           \
                            padding_right=5                          \
                            display="$display_id"                    \
                            background.drawing=on                    \
                            background.color=$UNFOCUSED_BG_COLOR     \
                            label.drawing=off                        \
                            label.font="sketchybar-app-font:Regular:16.0" \
                            label.padding_left=8                     \
                            label.padding_right=8                    \
                            label.y_offset=0                         \
                            click_script="aerospace workspace $sid")
  done
done

# Hidden item that subscribes to events and runs the compiled event handler.
# aerospace_workspace_change: fired by aerospace on workspace switch / window move.
# front_app_switched: fired by sketchybar when focused app changes (window open/close).
ARGS+=(--add item space_trigger center \
       --set space_trigger drawing=off \
                           script="$PLUGIN_DIR/aerospace_compiled.sh" \
       --subscribe space_trigger aerospace_workspace_change front_app_switched space_windows_change system_woke)

sketchybar "${ARGS[@]}"

# Cache workspace list for the event handler (refreshed on every sketchybar --reload)
aerospace list-workspaces --monitor all > /tmp/sketchybar_workspaces

# Let the event handler do initial styling (avoids duplicating its logic here)
sketchybar --trigger aerospace_workspace_change
