# Eval System

Three testing layers for the Ralph loop template.

## Layers

### 1. Loop Mechanics (`evals/loop-tests/`)

Deterministic tests for ralph.sh's bash logic. Uses `mock-claude.sh` to simulate Claude CLI output with zero API calls. Tests circuit breakers, exit detection, rate limiting, and git hook blocking.

```bash
./evals/run-eval.sh loop
```

### 2. Skeleton Integrity (`evals/smoke-test.sh`)

Tests that the project scaffolds correctly: `bun install`, `bun run test`, `bun run typecheck`, git init, placeholder replacement, and self-cleanup of `evals/` and `setup.sh`.

```bash
./evals/run-eval.sh smoke
```

### 3. Prompt Effectiveness (`evals/toy-projects/`)

End-to-end eval using real API calls against toy projects. Runs the full Ralph loop and captures results for manual scoring.

```bash
./evals/run-eval.sh prompt                 # calculator (default, 15 iterations)
./evals/run-eval.sh prompt calculator      # explicit calculator
./evals/run-eval.sh prompt task-queue      # task-queue (20 iterations default)
./evals/run-eval.sh prompt task-queue 25   # task-queue with custom iteration limit
```

#### Toy Projects

**calculator** — Baseline project. 5 simple stories (add, subtract, multiply, divide, expression parser). Validates the basic loop works: vertical slicing, TDD, clean exit. Run this first.

**task-queue** — Stress-test project. 10 stories covering architectural decisions, async testing, refactoring existing code, system boundary mocking (timers, file system), cross-module integration, dependency injection, and TypeScript generics. Designed to expose failure modes that trivial projects cannot. Run this after the calculator baseline passes.

## Directory Layout

```
evals/
  README.md              # This file
  run-eval.sh            # Orchestrator: loop | smoke | prompt | all
  analyse-run.sh         # Post-run analysis of a prompt eval
  scorecard-template.md  # Manual scoring template
  failure-taxonomy.md    # Catalogue of observed failure modes
  prompt-changelog.md    # Track prompt changes vs eval results
  loop-tests/
    mock-claude.sh       # Fake Claude CLI for deterministic testing
    test-circuit-breaker.sh
    test-exit-detection.sh
    test-rate-limiting.sh
    test-hook-blocking.sh
    run-loop-tests.sh    # Runs all loop tests
  smoke-test.sh
  toy-projects/
    calculator/
      prd.json           # Toy PRD with 5 user stories
      expected.md        # What a successful run looks like
    task-queue/
      prd.json           # Stress-test PRD with 10 user stories
      expected.md        # Expected outcomes and failure modes to watch for
  runs/                  # Gitignored — prompt eval output goes here
    .gitkeep
```

## Notes

- `evals/runs/` is gitignored. Eval output stays local.
- The entire `evals/` directory is stripped when scaffolding a real project via `setup.sh`.
- Loop tests and smoke tests are free (no API calls). Run them liberally.
- Prompt evals cost API credits. Run sparingly and review results with `analyse-run.sh`.
- Use `scorecard-template.md` for manual assessment after prompt evals.
- Track failure patterns in `failure-taxonomy.md`.
