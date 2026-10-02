#!/bin/sh

tmux kill-session -t caffeinate 2>/dev/null
tmux new-session -d -s caffeinate -n caffeinate
tmux send-keys -t caffeinate:caffeinate 'caffeinate -d' C-m
