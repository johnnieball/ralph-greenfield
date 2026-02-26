#!/bin/bash
set -e

# Ensure bun is on PATH
export PATH="$HOME/.bun/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

cleanup() {
  if [ -n "$TMPDIR_PATH" ] && [ -d "$TMPDIR_PATH" ]; then
    rm -rf "$TMPDIR_PATH"
  fi
}
trap cleanup EXIT

assert_true() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL: $label"
    FAIL=$(( FAIL + 1 ))
  fi
}

assert_false() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  FAIL: $label (expected false but got true)"
    FAIL=$(( FAIL + 1 ))
  else
    echo "  PASS: $label"
    PASS=$(( PASS + 1 ))
  fi
}

assert_contains() {
  local label="$1" file="$2" needle="$3"
  if grep -q "$needle" "$file" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$(( PASS + 1 ))
  else
    echo "  FAIL: $label (expected '$needle' in $file)"
    FAIL=$(( FAIL + 1 ))
  fi
}

echo "Smoke Test"
echo "=========="

# 1. Copy repo to temp directory (excluding .git, evals/, node_modules)
TMPDIR_PATH=$(mktemp -d)
rsync -a --exclude='.git' --exclude='evals/' --exclude='node_modules/' "$REPO_ROOT/" "$TMPDIR_PATH/"
cd "$TMPDIR_PATH"

# 2. Run setup.sh
echo "Running setup.sh test-project..."
set +e
bash ./setup.sh test-project > /dev/null 2>&1
setup_exit=$?
set -e

if [ "$setup_exit" -ne 0 ]; then
  echo "  FAIL: setup.sh exited with code $setup_exit"
  FAIL=$(( FAIL + 1 ))
  echo ""
  echo "Smoke tests: $PASS passed, $FAIL failed"
  exit 1
fi

# 3. Assert bun install succeeded
assert_true "bun install succeeded (node_modules exists)" test -d node_modules

# 4. Assert bun run test exits cleanly
echo "Running bun run test..."
set +e
bun run test > /dev/null 2>&1
test_exit=$?
set -e
if [ "$test_exit" -eq 0 ]; then
  echo "  PASS: bun run test exits cleanly"
  PASS=$(( PASS + 1 ))
else
  echo "  FAIL: bun run test exited with code $test_exit"
  FAIL=$(( FAIL + 1 ))
fi

# 5. Assert bun run typecheck exits cleanly
echo "Running bun run typecheck..."
set +e
bun run typecheck > /dev/null 2>&1
typecheck_exit=$?
set -e
if [ "$typecheck_exit" -eq 0 ]; then
  echo "  PASS: bun run typecheck exits cleanly"
  PASS=$(( PASS + 1 ))
else
  echo "  FAIL: bun run typecheck exited with code $typecheck_exit"
  FAIL=$(( FAIL + 1 ))
fi

# 6. Assert git repo initialised on branch ralph/initial-build
assert_true "git repo initialised" test -d .git
current_branch=$(git branch --show-current 2>/dev/null || echo "")
if [ "$current_branch" = "ralph/initial-build" ]; then
  echo "  PASS: on branch ralph/initial-build"
  PASS=$(( PASS + 1 ))
else
  echo "  FAIL: expected branch ralph/initial-build, got '$current_branch'"
  FAIL=$(( FAIL + 1 ))
fi

# 7. Assert prd.json contains test-project
assert_contains "prd.json contains test-project" "plans/prd.json" "test-project"

# 8. Assert CLAUDE.md contains test-project
assert_contains "CLAUDE.md contains test-project" "CLAUDE.md" "test-project"

# 9. Assert evals/ directory does NOT exist
assert_false "evals/ directory does not exist" test -d evals

# 10. Assert setup.sh does NOT exist
assert_false "setup.sh does not exist" test -f setup.sh

echo ""
echo "Smoke tests: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
