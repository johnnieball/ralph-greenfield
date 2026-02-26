# [Project Name]

Describe your project here.

## Commands

- `bun run dev` - start dev server
- `bun run test` - run tests (Vitest)
- `bun run typecheck` - TypeScript type checking
- `bun run lint` - linting
- `bun run build` - production build

## Codebase Patterns

(Patterns will be added here by Ralph during iterations)

## Testing Strategy

TDD is mandatory. RED-GREEN-REFACTOR. Vertical slices only.

- Tests verify behaviour through public interfaces
- Mock only at system boundaries (external APIs, databases, time, file system)
- Never mock your own code
- One test, one implementation, repeat - no horizontal slicing
- See `skills/tdd/SKILL.md` for complete methodology

## Ralph Loop

This project is developed autonomously via `plans/ralph.sh`.

- Each iteration reads `plans/prd.json` for tasks
- Progress is tracked in `progress.txt`
- Commits use `RALPH:` prefix
- Protected files: `plans/`, `skills/`, `.ralphrc`, `CLAUDE.md`, `progress.txt`
- Run with: `./plans/ralph.sh 20`

## Progress File Hygiene

`progress.txt` is consumed on every iteration and costs context budget. Keep entries concise — sacrifice grammar for brevity. When a sprint or major feature is complete, archive old entries:

1. Move completed entries to `progress-archive-YYYY-MM-DD.txt`
2. Keep only the `## Codebase Patterns` section and the last 5-10 entries in `progress.txt`
3. The archive is for human reference only — Ralph doesn't read it
