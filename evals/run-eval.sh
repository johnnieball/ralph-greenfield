#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  echo "Usage: $0 [loop|smoke|prompt|all]"
  exit 1
}

run_loop() {
  echo "=== Loop Tests ==="
  bash "$SCRIPT_DIR/loop-tests/run-loop-tests.sh"
}

run_smoke() {
  echo ""
  echo "=== Smoke Test ==="
  bash "$SCRIPT_DIR/smoke-test.sh"
}

run_prompt() {
  echo ""
  echo "=== Prompt Effectiveness Eval ==="

  # 1. Create timestamped run directory
  TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
  RUN_DIR="$SCRIPT_DIR/runs/$TIMESTAMP"
  mkdir -p "$RUN_DIR"

  # 2. Copy repo to temp build directory
  TMPDIR_PATH=$(mktemp -d)
  trap "rm -rf $TMPDIR_PATH" EXIT
  rsync -a --exclude='.git' --exclude='evals/' --exclude='node_modules/' "$REPO_ROOT/" "$TMPDIR_PATH/"
  cd "$TMPDIR_PATH"

  # 3. Run setup.sh
  echo "Scaffolding calculator-eval..."
  bash ./setup.sh calculator-eval

  # 4. Copy calculator prd.json over the placeholder
  cp "$SCRIPT_DIR/toy-projects/calculator/prd.json" plans/prd.json

  # 5. Run ralph.sh, capturing output
  echo "Running Ralph loop (max 15 iterations)..."
  set +e
  bash ./plans/ralph.sh 15 > "$RUN_DIR/ralph-output.log" 2>&1
  RALPH_EXIT=$?
  set -e

  # 6. Copy artefacts to run directory
  echo "$RALPH_EXIT" > "$RUN_DIR/exit-code.txt"
  cp plans/prd.json "$RUN_DIR/prd.json" 2>/dev/null || true
  cp progress.txt "$RUN_DIR/progress.txt" 2>/dev/null || true
  git log --oneline --all > "$RUN_DIR/git-log.txt" 2>/dev/null || true

  INITIAL_SHA=$(git rev-list --max-parents=0 HEAD 2>/dev/null || echo "")
  if [ -n "$INITIAL_SHA" ]; then
    git diff --stat "$INITIAL_SHA" HEAD > "$RUN_DIR/diff-stat.txt" 2>/dev/null || true
  fi

  # 7. Build summary
  SUMMARY_FILE="$RUN_DIR/summary.txt"

  # Iteration count
  iteration_count=$(grep -c "ITERATION .* of" "$RUN_DIR/ralph-output.log" 2>/dev/null || echo "0")
  echo "Iterations: $iteration_count" > "$SUMMARY_FILE"

  # Stories passed
  if [ -f "$RUN_DIR/prd.json" ]; then
    total_stories=$(jq '.userStories | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "?")
    passed_stories=$(jq '[.userStories[] | select(.passes == true)] | length' "$RUN_DIR/prd.json" 2>/dev/null || echo "?")
    echo "Stories: $passed_stories/$total_stories passed" >> "$SUMMARY_FILE"
  fi

  # Exit condition
  if grep -q "Ralph complete" "$RUN_DIR/ralph-output.log" 2>/dev/null; then
    echo "Exit condition: Ralph complete (promise)" >> "$SUMMARY_FILE"
  elif grep -q "Ralph received EXIT_SIGNAL" "$RUN_DIR/ralph-output.log" 2>/dev/null; then
    echo "Exit condition: EXIT_SIGNAL" >> "$SUMMARY_FILE"
  elif grep -q "CIRCUIT BREAKER" "$RUN_DIR/ralph-output.log" 2>/dev/null; then
    echo "Exit condition: Circuit breaker" >> "$SUMMARY_FILE"
  elif grep -q "Ralph reached max iterations" "$RUN_DIR/ralph-output.log" 2>/dev/null; then
    echo "Exit condition: Max iterations" >> "$SUMMARY_FILE"
  elif grep -q "Ralph aborted" "$RUN_DIR/ralph-output.log" 2>/dev/null; then
    echo "Exit condition: Abort" >> "$SUMMARY_FILE"
  else
    echo "Exit condition: Unknown" >> "$SUMMARY_FILE"
  fi

  echo "Exit code: $RALPH_EXIT" >> "$SUMMARY_FILE"

  # 8. Copy scorecard template
  cp "$SCRIPT_DIR/scorecard-template.md" "$RUN_DIR/scorecard.md"

  # Print summary
  echo ""
  echo "--- Run Summary ---"
  cat "$SUMMARY_FILE"
  echo ""
  echo "Full run data: $RUN_DIR"
  echo "Review: $RUN_DIR/scorecard.md"
}

case "${1:-}" in
  loop)  run_loop ;;
  smoke) run_smoke ;;
  prompt) run_prompt ;;
  all)
    run_loop
    run_smoke
    run_prompt
    ;;
  *) usage ;;
esac
