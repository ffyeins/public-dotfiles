#!/bin/bash

source "$CONFIG_DIR/plugins/icon_map_fn.sh"

if [ "$SENDER" = "front_app_switched" ]; then
  icon_map "$INFO"
  sketchybar --set $NAME label="$INFO" icon="$icon_result"
fi
