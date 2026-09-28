#!/bin/sh

tmux kill-session -t caffeinate_session 2>/dev/null
tmux new-session -d -s caffeinate_session -n caffeinate
tmux send-keys -t caffeinate_session:caffeinate 'caffeinate -d' C-m
