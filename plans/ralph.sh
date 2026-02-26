#!/bin/bash
set -e

# Ensure bun is on PATH (installed to ~/.bun by default)
export PATH="$HOME/.bun/bin:$PATH"

# Architecture note: FRESH CONTEXT PER ITERATION
# ================================================
# Each iteration spawns a fresh Claude process via --print mode.
# State lives in files (prd.json, progress.txt) and git, NOT in
# conversation history. This prevents "context rot" — the degradation
# in output quality as context windows fill up.
#
# DO NOT switch to --continue mode or the stop-hook plugin.
# Accumulated context causes compaction events where the model loses
# track of critical specifications. Fresh context = peak intelligence
# on every iteration.
# ================================================

# Source configuration
if [ -f ".ralphrc" ]; then
  source .ralphrc
fi

# Defaults (overridden by .ralphrc)
MAX_CALLS_PER_HOUR=${MAX_CALLS_PER_HOUR:-60}
MAX_ITERATIONS=${MAX_ITERATIONS:-20}
CB_NO_PROGRESS_THRESHOLD=${CB_NO_PROGRESS_THRESHOLD:-3}
CB_SAME_ERROR_THRESHOLD=${CB_SAME_ERROR_THRESHOLD:-5}

# Argument: iteration count overrides MAX_ITERATIONS
if [ -n "$1" ]; then
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS="$1"
  else
    echo "Usage: $0 [iterations]"
    exit 1
  fi
fi

# Kickoff gate — ensure PRD has been reviewed before AFK execution
if [ "${RALPH_SKIP_KICKOFF:-0}" != "1" ]; then
  if [ ! -f ".ralph-kickoff-complete" ]; then
    echo "ERROR: Kickoff not completed. Run ./plans/kickoff.sh first."
    echo "       To skip: RALPH_SKIP_KICKOFF=1 ./plans/ralph.sh"
    exit 1
  fi
fi

# jq filters for stream-json output
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
final_result='select(.type == "result").result // empty'

# Circuit breaker state
no_progress_count=0
same_error_count=0
last_error_line=""
last_ralph_sha=""

# Rate limiting
CALL_COUNT_FILE=".ralph-call-count"

check_rate_limit() {
  local current_hour
  current_hour=$(date +"%Y%m%d%H")

  if [ -f "$CALL_COUNT_FILE" ]; then
    local stored_hour stored_count
    stored_hour=$(head -1 "$CALL_COUNT_FILE")
    stored_count=$(tail -1 "$CALL_COUNT_FILE")

    if [ "$stored_hour" = "$current_hour" ]; then
      if [ "$stored_count" -ge "$MAX_CALLS_PER_HOUR" ]; then
        local mins_left
        mins_left=$(( 60 - $(date +%-M) ))
        echo "Rate limit reached ($MAX_CALLS_PER_HOUR/hr). Sleeping ${mins_left}m until next hour..."
        sleep $(( mins_left * 60 ))
        echo "$current_hour" > "$CALL_COUNT_FILE"
        echo "1" >> "$CALL_COUNT_FILE"
        return
      fi
      echo "$current_hour" > "$CALL_COUNT_FILE"
      echo "$(( stored_count + 1 ))" >> "$CALL_COUNT_FILE"
      return
    fi
  fi

  echo "$current_hour" > "$CALL_COUNT_FILE"
  echo "1" >> "$CALL_COUNT_FILE"
}

fmt_time() {
  local secs=$1
  if [ "$secs" -ge 60 ]; then
    printf "%dm%02ds" $(( secs / 60 )) $(( secs % 60 ))
  else
    printf "%ds" "$secs"
  fi
}

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS"

TMPFILES=()
trap 'rm -f "${TMPFILES[@]}"' EXIT

loop_start=$(date +%s)

for (( i=1; i<=MAX_ITERATIONS; i++ )); do
  tmpfile=$(mktemp)
  TMPFILES+=("$tmpfile")

  iter_start=$(date +%s)
  last_ralph_sha_before="$last_ralph_sha"

  # Rate limit check
  check_rate_limit

  # Gather RALPH commit history
  ralph_commits=$(git log --grep="RALPH" -n 10 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No RALPH commits found")

  # Build prompt
  prompt="$(cat plans/prompt.md)

Previous RALPH commits:
$ralph_commits"

  # Build claude command
  claude_cmd=(claude --dangerously-skip-permissions --print --output-format stream-json --verbose -p "$prompt")
  if [ -n "$ALLOWED_TOOLS" ]; then
    claude_cmd+=(--allowedTools "$ALLOWED_TOOLS")
  fi

  # Run claude and stream output
  "${claude_cmd[@]}" \
    | grep --line-buffered '^{' \
    | tee "$tmpfile" \
    | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  # Check <promise> exit signals
  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]] || [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo ""
    echo "Ralph complete after $i iterations."
    exit 0
  fi

  if [[ "$result" == *"<promise>ABORT</promise>"* ]]; then
    echo "Ralph aborted after $i iterations."
    exit 1
  fi

  # Check RALPH_STATUS block for EXIT_SIGNAL
  exit_signal=$(echo "$result" | sed -n '/---RALPH_STATUS---/,/---END_RALPH_STATUS---/p' | grep -i "EXIT_SIGNAL:" | head -1 | awk '{print $2}' || echo "")
  if [ "$exit_signal" = "true" ]; then
    echo ""
    echo "Ralph received EXIT_SIGNAL after $i iterations."
    exit 0
  fi

  # Circuit breaker: no progress detection (check for new RALPH commit)
  latest_ralph_sha=$(git log --grep="RALPH" -n 1 --format="%H" 2>/dev/null || echo "")
  if [ "$latest_ralph_sha" = "$last_ralph_sha" ]; then
    no_progress_count=$(( no_progress_count + 1 ))
  else
    no_progress_count=0
  fi
  last_ralph_sha="$latest_ralph_sha"

  if [ "$no_progress_count" -ge "$CB_NO_PROGRESS_THRESHOLD" ]; then
    echo ""
    echo "CIRCUIT BREAKER: No file changes in $no_progress_count consecutive iterations. Halting."
    exit 1
  fi

  # Circuit breaker: same error detection
  current_last_line=$(echo "$result" | tail -1)
  if [ "$current_last_line" = "$last_error_line" ] && [ -n "$current_last_line" ]; then
    same_error_count=$(( same_error_count + 1 ))
  else
    same_error_count=0
  fi
  last_error_line="$current_last_line"

  if [ "$same_error_count" -ge "$CB_SAME_ERROR_THRESHOLD" ]; then
    echo ""
    echo "CIRCUIT BREAKER: Same output repeated $same_error_count times. Halting."
    exit 1
  fi

  # Build end-of-iteration summary line
  iter_end=$(date +%s)
  iter_elapsed=$(( iter_end - iter_start ))
  total_elapsed=$(( iter_end - loop_start ))

  # Parse story progress from prd.json
  story_done="?"
  story_total="?"
  if [ -f "plans/prd.json" ]; then
    story_total=$(jq '.userStories | length' plans/prd.json 2>/dev/null || echo "?")
    story_done=$(jq '[.userStories[] | select(.passes == true)] | length' plans/prd.json 2>/dev/null || echo "?")
  fi

  # Parse current story ID from RALPH_STATUS
  current_story=$(echo "$result" | sed -n '/---RALPH_STATUS---/,/---END_RALPH_STATUS---/p' | grep -i "CURRENT_STORY:" | head -1 | awk '{print $2}' || echo "")

  # Parse test status from RALPH_STATUS
  test_status=$(echo "$result" | sed -n '/---RALPH_STATUS---/,/---END_RALPH_STATUS---/p' | grep -i "TESTS_STATUS:" | head -1 | awk '{print $2}' || echo "")
  test_status=$(echo "$test_status" | tr '[:upper:]' '[:lower:]')
  if [ -z "$test_status" ]; then
    test_status="unknown"
  fi

  # Determine commit status
  if [ "$latest_ralph_sha" != "$last_ralph_sha_before" ]; then
    commit_label="committed"
    # Try to get story ID from latest commit message
    if [ -z "$current_story" ]; then
      current_story=$(git log --grep="RALPH" -n 1 --format="%s" 2>/dev/null | grep -oE 'US-[0-9]+' | head -1 || echo "")
    fi
    summary_line="[$i/$MAX_ITERATIONS]"
    if [ -n "$current_story" ]; then
      # Get story title from prd.json
      story_title=$(jq -r --arg id "$current_story" '.userStories[] | select(.id == $id) | .title // empty' plans/prd.json 2>/dev/null || echo "")
      if [ -n "$story_title" ]; then
        summary_line="$summary_line [$current_story] - $story_title"
      else
        summary_line="$summary_line [$current_story]"
      fi
    fi
    summary_line="$summary_line | $story_done/$story_total done | $commit_label | tests: $test_status | cb: $no_progress_count/$CB_NO_PROGRESS_THRESHOLD | $(fmt_time $iter_elapsed) ($(fmt_time $total_elapsed) total)"
  else
    summary_line="[$i/$MAX_ITERATIONS] no commit | $story_done/$story_total done | tests: $test_status | cb: $no_progress_count/$CB_NO_PROGRESS_THRESHOLD | $(fmt_time $iter_elapsed) ($(fmt_time $total_elapsed) total)"
  fi

  echo ""
  echo "$summary_line"
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS)."
exit 1
