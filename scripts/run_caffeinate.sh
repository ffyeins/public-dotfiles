#!/bin/sh

session="z_caffeinate"

tmux kill-session -t "$session" 2>/dev/null
tmux new-session -d -s "$session" -n caffeinate
tmux send-keys -t "$session:caffeinate" 'caffeinate -d' C-m
