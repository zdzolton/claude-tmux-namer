#!/usr/bin/env zsh
#
# tmux-namer.zsh - Rename tmux window based on Claude conversation context
#
# Uses Haiku to generate a 2-4 word phrase describing the work, then renames
# the tmux window where Claude is actually running.
#
# Reads transcript_path from the Stop hook payload (stdin) and sends only a
# brief excerpt to Haiku, avoiding the expensive cache_create cost that
# --continue incurs on a cold or expired cache.
#

# Ensure standard tool locations are in PATH — the hook runs with a restricted
# PATH that may omit /usr/bin and /opt/homebrew/bin.
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Exit silently if not in tmux
[[ -z $TMUX ]] && exit 0

# Determine which tmux window Claude is running in:
# 1. Get this hook's parent PID (the Claude process)
# 2. Get its TTY
# 3. Find which tmux pane owns that TTY
claude_tty=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
[[ -z $claude_tty ]] && exit 0
# Normalize TTY path (Linux: pts/N, macOS: ttysNNN)
[[ $claude_tty != /* ]] && claude_tty="/dev/$claude_tty"

window_target=$(tmux list-panes -a -F '#{pane_tty} #{session_name}:#{window_id}' 2>/dev/null | \
  awk -v tty="$claude_tty" '$1 == tty { print $2; exit }')
[[ -z $window_target ]] && exit 0

# Log file for cost tracking
LOG_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/claude-tmux-namer/cost.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Read the Stop hook payload from stdin. Claude Code pipes a JSON object
# containing transcript_path; cat returns immediately when the pipe closes.
hook_payload=$(cat 2>/dev/null)
transcript_path=$(jq -r '.transcript_path // empty' 2>/dev/null <<< "$hook_payload")

# Background the API call so the hook returns immediately.
{
  # Build a prompt from the first 3 user messages in the transcript (capped at
  # 300 chars each). This avoids the large cache_create cost that --continue
  # triggers by loading the full conversation into a cold cache.
  if [[ -z $transcript_path || ! -f $transcript_path ]]; then
    echo "$(date -Iseconds) error=\"no transcript available\"" >> "$LOG_FILE"
    exit 0
  fi

  context=$(grep -m 3 '"type":"user"' "$transcript_path" \
    | jq -r '
        .message.content |
        if type == "array" then
          map(select(.type == "text") | .text) | join(" ")
        elif type == "string" then .
        else empty
        end
      ' 2>/dev/null \
    | awk '{ print substr($0, 1, 300) }' \
    | tr '\n' ' ')

  if [[ -z $context ]]; then
    echo "$(date -Iseconds) error=\"empty transcript context\"" >> "$LOG_FILE"
    exit 0
  fi

  prompt="Work session transcript excerpt: ${context}

Generate a 2-4 word lowercase phrase describing this work. Output ONLY the phrase, nothing else."

  output=$(claude \
    --model haiku \
    --output-format=stream-json \
    --verbose \
    --print \
    --settings '{"disableAllHooks": true}' \
    -p "$prompt" \
    2>&1)

  # Check for API errors and skip rename
  if echo "$output" | grep -q '"type":"error"'; then
    error_msg=$(echo "$output" | grep '"type":"error"' | jq -r '.error.message // "unknown"' 2>/dev/null | head -1)
    echo "$(date -Iseconds) error=\"API error\" message=\"${error_msg}\"" >> "$LOG_FILE"
    exit 0
  fi

  # Extract name and log cost metrics
  result_line=$(echo "$output" | grep '"type":"result"' | head -1)
  name=$(echo "$result_line" | jq -r '.result // empty' | tr -d '\n')

  if [[ -n $result_line ]]; then
    cost=$(echo "$result_line" | jq -r '.total_cost_usd // 0')
    input_tokens=$(echo "$result_line" | jq -r '.usage.input_tokens // 0')
    output_tokens=$(echo "$result_line" | jq -r '.usage.output_tokens // 0')
    cache_read=$(echo "$result_line" | jq -r '.usage.cache_read_input_tokens // 0')
    cache_create=$(echo "$result_line" | jq -r '.usage.cache_creation_input_tokens // 0')
    safe_name=${name//\"/\\\"}
    echo "$(date -Iseconds) cost=\$${cost} input=${input_tokens} output=${output_tokens} cache_read=${cache_read} cache_create=${cache_create} name=\"${safe_name}\"" >> "$LOG_FILE"
  else
    echo "$(date -Iseconds) error=\"no result line found\"" >> "$LOG_FILE"
  fi

  # Sanitize and truncate, then rename
  name=${name//[^a-zA-Z0-9 ]/}
  (( ${#name} > 40 )) && name="${name:0:40}"
  [[ -n $name ]] && tmux rename-window -t "$window_target" "$name"
} &!
