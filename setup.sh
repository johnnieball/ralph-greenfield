#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./setup.sh <project-name>"
  echo "Example: ./setup.sh my-saas-app"
  exit 1
fi

PROJECT_NAME="$1"
echo "Setting up $PROJECT_NAME..."

# Portable in-place sed (macOS requires '' as separate arg)
portable_sed() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Replace placeholders
portable_sed "s/PROJECT_NAME/$PROJECT_NAME/g" package.json
portable_sed "s/PROJECT_NAME/$PROJECT_NAME/g" plans/prd.json
portable_sed "s/\[Project Name\]/$PROJECT_NAME/g" CLAUDE.md

# Strip eval infrastructure (not needed in real projects)
rm -rf evals/
rm -f setup.sh

# Set permissions
chmod +x plans/ralph.sh
chmod +x plans/kickoff.sh
chmod +x .claude/hooks/block-dangerous-git.sh

# Initialise git first (husky's prepare script needs .git)
rm -rf .git
git init

# Install dependencies (runs prepare script which sets up husky)
bun install

# Create pre-commit hook
cat > .husky/pre-commit << 'EOF'
bunx lint-staged
bun run typecheck
bun run test
EOF

# Initial commit
git add -A
git commit -m "chore: scaffold $PROJECT_NAME via ralph-greenfield"
git checkout -b ralph/initial-build

echo ""
echo "Done. Next steps:"
echo "  1. Edit plans/prd.json with your user stories"
echo "  2. Run ./plans/kickoff.sh to review the PRD"
echo "  3. Run ./plans/ralph.sh 20"
