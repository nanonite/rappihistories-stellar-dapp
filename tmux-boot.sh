#!/bin/bash
# Start tmux session in detached mode (called from /etc/sandbox-persistent.sh)
SESSION="dev"

# Only start if session doesn't already exist
tmux has-session -t "$SESSION" 2>/dev/null && exit 0

# Start detached tmux session with bash in first window, with proper PATH
tmux new-session -d -s "$SESSION" -n "opencode" \
  "bash -l -c 'export PATH=/usr/local/bin:/usr/local/cargo/bin:\$PATH; exec bash -l'"

# Wait for bash to be ready, then send opencode command
sleep 1
tmux send-keys -t "$SESSION:opencode" "opencode" Enter

# Create second window with interactive bash shell
tmux new-window -t "$SESSION" -n "shell" \
  "bash -l -c 'export PATH=/usr/local/bin:/usr/local/cargo/bin:\$PATH; exec bash -l'"

# Select the opencode window by default
tmux select-window -t "$SESSION:opencode"
