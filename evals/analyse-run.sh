#!/bin/bash
set -e

if [ -z "$1" ] || [ ! -d "$1" ]; then
  echo "Usage: $0 evals/runs/<timestamp>/"
  exit 1
fi

RUN_DIR="$1"

echo "=== Run Analysis ==="
echo "Directory: $RUN_DIR"
echo ""

# Exit condition and exit code
if [ -f "$RUN_DIR/exit-code.txt" ]; then
  exit_code=$(cat "$RUN_DIR/exit-code.txt")
  echo "Exit code: $exit_code"
fi

if [ -f "$RUN_DIR/summary.txt" ]; then
  echo ""
  cat "$RUN_DIR/summary.txt"
fi

echo ""

# Iteration count
if [ -f "$RUN_DIR/ralph-output.log" ]; then
  iteration_count=$(grep -c "ITERATION .* of" "$RUN_DIR/ralph-output.log" 2>/dev/null || echo "0")
  echo "Iteration count: $iteration_count"
fi

# Stories completed
if [ -f "$RUN_DIR/prd.json" ]; then
  total=$(jq '.userStories | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "?")
  passed=$(jq '[.userStories[] | select(.passes == true)] | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "?")
  echo "Stories completed: $passed / $total"
fi

echo ""

# RALPH commits
if [ -f "$RUN_DIR/git-log.txt" ]; then
  ralph_commits=$(grep "RALPH" "$RUN_DIR/git-log.txt" 2>/dev/null || echo "")
  if [ -n "$ralph_commits" ]; then
    echo "RALPH commits:"
    echo "$ralph_commits" | sed 's/^/  /'
  else
    echo "RALPH commits: none"
  fi
fi

echo ""

# Circuit breaker activations
if [ -f "$RUN_DIR/ralph-output.log" ]; then
  cb=$(grep "CIRCUIT BREAKER" "$RUN_DIR/ralph-output.log" 2>/dev/null || echo "")
  if [ -n "$cb" ]; then
    echo "Circuit breaker activations:"
    echo "$cb" | sed 's/^/  /'
  else
    echo "Circuit breaker activations: none"
  fi
fi

# Progress file
if [ -f "$RUN_DIR/progress.txt" ]; then
  line_count=$(wc -l < "$RUN_DIR/progress.txt" | tr -d ' ')
  echo "progress.txt: $line_count lines"

  if grep -q "## Codebase Patterns" "$RUN_DIR/progress.txt" 2>/dev/null; then
    echo "Codebase Patterns section: present"
  else
    echo "Codebase Patterns section: MISSING"
  fi
else
  echo "progress.txt: NOT FOUND"
fi

echo ""

# Flags
echo "=== Flags ==="
flags=0

if [ -f "$RUN_DIR/git-log.txt" ]; then
  ralph_count=$(grep -c "RALPH" "$RUN_DIR/git-log.txt" 2>/dev/null || echo "0")
  if [ "$ralph_count" -eq 0 ]; then
    echo "WARNING: Zero RALPH commits"
    flags=$(( flags + 1 ))
  fi
fi

if [ -f "$RUN_DIR/ralph-output.log" ]; then
  iteration_count=$(grep -c "ITERATION .* of" "$RUN_DIR/ralph-output.log" 2>/dev/null || echo "0")
  if [ "$iteration_count" -gt 10 ]; then
    echo "WARNING: More than 10 iterations for 5 stories ($iteration_count iterations)"
    flags=$(( flags + 1 ))
  fi
fi

if [ -f "$RUN_DIR/exit-code.txt" ] && [ -f "$RUN_DIR/prd.json" ]; then
  exit_code=$(cat "$RUN_DIR/exit-code.txt")
  total=$(jq '.userStories | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "0")
  passed=$(jq '[.userStories[] | select(.passes == true)] | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "0")
  if [ "$exit_code" = "1" ] && [ "$passed" = "$total" ] && [ "$total" -gt 0 ]; then
    echo "WARNING: Exit code 1 but all stories passing"
    flags=$(( flags + 1 ))
  fi
fi

if [ "$flags" -eq 0 ]; then
  echo "No flags raised."
fi
