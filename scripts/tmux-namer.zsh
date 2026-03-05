#!/usr/bin/env zsh
#
# tmux-namer.zsh - Rename tmux window based on Claude conversation context
#
# Uses Haiku in background to generate a 2-4 word phrase describing the work,
# then renames the tmux window where Claude is actually running.
#

# Exit silently if not in tmux
[[ -z $TMUX ]] && exit 0

# Find the window where Claude is running by tracing the process tree
# 1. Get parent PID (Claude process)
# 2. Get its TTY
# 3. Find which tmux pane has that TTY
# 4. Extract the window target

claude_tty=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
[[ -z $claude_tty ]] && exit 0

# Normalize TTY path (Linux: pts/N, macOS: ttysNNN)
[[ $claude_tty != /* ]] && claude_tty="/dev/$claude_tty"

# Find the tmux pane with this TTY and get its window
window_target=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_id}' 2>/dev/null | \
  awk -v tty="$claude_tty" '$1 == tty { print $2; exit }')

[[ -z $window_target ]] && exit 0

# Log file for cost tracking
LOG_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/claude-tmux-namer/cost.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Background the API call to avoid blocking
{
  output=$(
    claude --continue \
      --model haiku \
      --output-format=stream-json \
      --verbose \
      --print \
      --settings '{"disableAllHooks": true}' \
      -p "Generate a 2-4 word lowercase phrase describing this work session. Output ONLY the phrase, nothing else." \
      2>&1
  )

  # Check for API errors and skip rename
  if echo "$output" | grep -q '"type":"error"'; then
    error_msg=$(echo "$output" | grep '"type":"error"' | jq -r '.error.message // "unknown"' 2>/dev/null | head -1)
    echo "$(date -Iseconds) error=\"API error\" message=\"${error_msg}\"" >> "$LOG_FILE"
    exit 0
  fi

  # Extract cost from result message and log it
  result_line=$(echo "$output" | grep '"type":"result"' | head -1)

  # Extract the name from the result line (avoids jq parse errors from unescaped
  # control characters that the CLI emits inside thinking block content)
  name=$(echo "$result_line" | jq -r '.result // empty' | tr -d '\n')
  if [[ -n $result_line ]]; then
    cost=$(echo "$result_line" | jq -r '.total_cost_usd // 0')
    input_tokens=$(echo "$result_line" | jq -r '.usage.input_tokens // 0')
    output_tokens=$(echo "$result_line" | jq -r '.usage.output_tokens // 0')
    cache_read=$(echo "$result_line" | jq -r '.usage.cache_read_input_tokens // 0')
    cache_create=$(echo "$result_line" | jq -r '.usage.cache_creation_input_tokens // 0')

    # Escape quotes in name for log output
    safe_name=${name//\"/\\\"}
    echo "$(date -Iseconds) cost=\$${cost} input=${input_tokens} output=${output_tokens} cache_read=${cache_read} cache_create=${cache_create} name=\"${safe_name}\"" >> "$LOG_FILE"
  else
    # Log extraction failure for debugging
    echo "$(date -Iseconds) error=\"no result line found\"" >> "$LOG_FILE"
  fi

  # Sanitize name to alphanumeric and spaces only
  name=${name//[^a-zA-Z0-9 ]/}

  # Truncate if too long (40 char limit for status bar readability)
  (( ${#name} > 40 )) && name="${name:0:40}"

  # Only rename if we got a non-empty result
  [[ -n $name ]] && tmux rename-window -t "$window_target" "$name"
} &!
