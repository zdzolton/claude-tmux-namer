#!/usr/bin/env zsh
#
# tmux-namer-start.zsh - Set a placeholder tmux window name when a Claude session starts
#
# Prevents the Claude CLI version number from appearing as the window name.
# tmux's allow-rename picks up whatever terminal title Claude sets on startup
# (which includes its version, e.g. "2.1.84"). This script races ahead of that
# by immediately setting "claude..." via a tmux command (which allow-rename cannot
# override). The Stop hook will replace this placeholder with a descriptive name.
#

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

[[ -z $TMUX ]] && exit 0

claude_tty=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
[[ -z $claude_tty ]] && exit 0
[[ $claude_tty != /* ]] && claude_tty="/dev/$claude_tty"

window_target=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_id}' 2>/dev/null | \
  awk -v tty="$claude_tty" '$1 == tty { print $2; exit }')
[[ -z $window_target ]] && exit 0

tmux rename-window -t "$window_target" "claude..."
