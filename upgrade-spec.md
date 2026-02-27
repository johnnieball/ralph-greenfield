# Ralph-Greenfield Upgrade Spec

**Purpose:** Execute these changes to the ralph-greenfield template repo, then run the validation checklist.
**Repo location:** This file should be in the repo root. All paths are relative to repo root.
**Approach:** Read every file before editing it. Make the changes in the order listed. Run validation at the end.

---

## 1. Prompt Tightening - `plans/prompt.md`

Read the full file first. Then make these targeted edits to specific phases. Do not rewrite sections that aren't mentioned here.

### 1a. GREEN phase - add minimal implementation rule

Find the GREEN phase section. Add the following guidance (integrate naturally with existing text, don't just append):

- GREEN means the smallest change that makes the current RED test pass. Nothing more.
- Self-check before writing GREEN code: state in one sentence what you will change. If that sentence contains "and", you're probably doing too much.
- If your next RED test passes immediately without any code changes, that's a signal your previous GREEN was too large. One occurrence per story is fine - it means the minimal implementation naturally covered the next AC. Multiple in a row means you need to write smaller GREEN steps.

### 1b. EXPLORATION phase - add skill file relevance check

Find the EXPLORATION phase section. Add:

- Check which skill reference files are relevant to this story. Scan the filenames in `skills/tdd/` and read any that relate to your planned approach. Examples: if your story involves dependency injection or system boundaries, read `mocking.md`. If it involves module boundaries or public API design, read `deep-modules.md` and `interface-design.md`. If it involves restructuring existing code, read `refactoring.md`. If none are relevant, skip this step - but if you find yourself reaching for a pattern you're unsure about, check the skill files before inventing your own.

### 1c. EXPLORATION phase - add signature change planning

In the same EXPLORATION section, add:

- If this story requires changing a shared function's signature (adding parameters, changing return types), plan the ripple before writing the first test. List all callers and test files that will need updating. Budget the caller updates into your GREEN step rather than fixing them reactively after tests break.

### 1d. EXPLORATION phase - add structural awareness check

In the same EXPLORATION section, add:

- Before planning your approach, quickly scan the modules you'll be touching. Check: are any functions you'll modify already over ~50 lines? Is the function signature already at 4+ parameters? Is data being threaded through multiple calls unchanged? If so, plan a refactor as part of this iteration's work rather than adding to the debt.

### 1e. REFACTOR phase - add measurable triggers

Find the REFACTOR phase section. Add concrete triggers (integrate with existing text):

- Check the following triggers against the code you've written or modified this iteration. If any are true, refactor before committing:
  - Any function exceeds ~50 lines - extract helpers
  - Any function signature has more than 4 parameters - convert trailing params to an options/config object
  - The same data (e.g. theme, config, logger) is threaded through 3+ function calls unchanged - introduce a context object
  - You have 3+ custom error classes with no shared base - consider a base error class
  - You're copy-pasting a pattern for the third time - extract it
- If a needed refactor is too large to do safely within this iteration, note it as technical debt in progress.txt under a "Technical Debt" heading and flag it in RALPH_STATUS RECOMMENDATION field.

### 1f. PROGRESS phase - add compression rule

Find the PROGRESS phase section. Add:

- Before appending your progress entry, check the length of progress.txt. If it's getting long (over ~100 lines), compress it: summarise all completed stories older than the last 5 into a "Completed Work Summary" section at the top (max 20 lines). Keep the Codebase Patterns section, the Technical Debt section (if any), and the last 5 detailed iteration entries. Remove the detailed entries for older iterations. The goal is to keep progress.txt informative without growing unbounded.

---

## 2. Architecture Intent File

### 2a. Create `plans/architecture.md`

Create the file with PROJECT_NAME placeholders (matching the pattern used in `plans/prd.json`):

```markdown
# Architecture - PROJECT_NAME

## Modules

<!-- Generated from PRD at kickoff. List each source module and its single responsibility. -->
<!-- Format: `src/module.ts` - One sentence describing what this module owns. -->
<!-- Example: `src/schema.ts` - Owns all Zod schemas and parse functions. No I/O, no rendering. -->

## Dependency Rules

<!-- Generated from PRD at kickoff. State which modules can import from which. -->
<!-- Format: "X can import from Y. X must never import from Z." -->
<!-- Keep to the critical boundaries only - don't list every valid import. -->

## Hard Constraints

<!-- 3-5 inviolable rules. No rationale, just the rule. -->
<!-- Example: "All file I/O is isolated in loader and builder modules. Renderer and schema modules must be pure." -->
<!-- Example: "Content types use Zod discriminated unions. Do not use type assertions to narrow." -->
```

### 2b. Wire into CLAUDE.md

Read `CLAUDE.md` first. Add a single line in the appropriate place:

- "If `plans/architecture.md` exists and has been filled in, read it at the start of each iteration. Check your planned changes against the dependency rules and hard constraints."

The conditional ("if it exists and has been filled in") is important - the template ships with placeholder comments, and the agent shouldn't try to follow empty placeholder sections.

### 2c. Wire into setup.sh

Read `setup.sh` first. Add `plans/architecture.md` to the find-and-replace list so PROJECT_NAME gets substituted, matching how prd.json is handled.

---

## 3. Linter Setup

### 3a. Research the right linter

Before choosing a linter, check what works best with the existing Bun + Vitest + Prettier setup. Key considerations:

- Must work with Bun (not just Node/npm)
- Must not conflict with existing Prettier config (`.prettierrc`)
- Must not conflict with existing lint-staged config (`.lintstagedrc`)
- Should catch real bugs: unused variables, unreachable code, consistent returns, no implicit any
- Should NOT enforce style rules (Prettier handles formatting)

Candidates to evaluate: Biome (fast, works with Bun, replaces both ESLint and Prettier but we already have Prettier), ESLint with typescript-eslint (more mature, heavier), oxlint (fast, Rust-based, still young).

**[Important]:** If Biome is chosen and it replaces Prettier, update `.prettierrc` and `.lintstagedrc` accordingly. If ESLint is chosen alongside Prettier, make sure they don't conflict. Pick whichever is the cleanest integration with the existing setup.

### 3b. Install and configure

Install the chosen linter. Create a minimal config that enables only bug-catching rules. No style rules, no opinionated formatting rules.

### 3c. Wire into pre-commit

Read `.lintstagedrc` and `.husky/pre-commit`. Add the linter to the pre-commit pipeline so it runs alongside the existing prettier, typecheck, and test checks.

### 3d. Wire into prompt.md

The beast run showed "Lint: no linter configured (skip)" in the FEEDBACK LOOPS phase. This should now show actual lint results. Check that the FEEDBACK LOOPS phase in prompt.md references linting, and update if needed so the agent runs and reports lint results.

### 3e. Verify it works

Run the linter against the existing template source files (`src/index.ts` at minimum). Fix any issues it finds. Ensure the pre-commit hook runs cleanly.

---

## 4. Test Quality Guidance - Skill Files

### 4a. HTML assertion guidance in `skills/tdd/tests.md`

Read the file first. Add a short section (5-10 lines max):

- For HTML output testing, `toContain` is fine for simple presence checks ("does the output include a nav element?"). For structural assertions ("does the nav contain exactly 3 links with the second one marked as current?"), use a more targeted approach - either a lightweight DOM parser if available, or scope your string assertions to a specific section of the HTML rather than the full document.
- Rule of thumb: if your assertion uses `not.toContain` on a string that might appear elsewhere in the HTML, the test is brittle. Narrow the search scope.

### 4b. Edge case heuristics in `skills/tdd/tests.md`

In the same file, add:

- After covering the happy path and the error path for each AC, consider one edge case: what happens with empty input? Input at boundary sizes? The target pattern appearing inside a code block or escaped context? Conflicting but individually valid inputs? You don't need exhaustive edge case coverage - one well-chosen edge case per AC is enough.

### 4c. Dependency verification in `skills/tdd/SKILL.md`

Read the file first. Add a short note:

- After installing a new dependency, verify its API before using it. Check the return types (don't assume sync vs async from a previous major version). Run `bun run typecheck` after your first usage to catch type mismatches early.

---

## 5. Progress File Template Update

### 5a. Update `progress.txt`

Read the current progress.txt template. If there isn't already a "Technical Debt" section header, add one below the "Codebase Patterns" section:

```
## Codebase Patterns
(patterns added during the build)

## Technical Debt
(refactoring needs noted during the build - address when capacity allows)
```

This gives the refactor triggers from Task 1e somewhere to write their findings.

---

## 6. Validation

### 6a. Run the validation checklist

Run every check in `/Users/johnnieball/projects/ralph-bootstrap/ralph-validate.md` against the updated repo. Report results - all 30 points should pass. If any fail, fix them or document why the failure is expected given the changes made.

### 6b. Smoke test the pre-commit pipeline

Run `git add -A && git commit --dry-run` (or equivalent) to verify the full pre-commit pipeline executes: prettier, typecheck, linter, tests. All should pass.

### 6c. Verify setup.sh still works

Run `./setup.sh test-project` in a temp directory to confirm the full setup flow works with the new architecture.md file and any linter config changes.
