#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./setup.sh <project-name>"
  echo "Example: ./setup.sh my-saas-app"
  exit 1
fi

PROJECT_NAME="$1"
echo "Setting up $PROJECT_NAME..."

# Replace placeholders
if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_CMD="sed -i ''"
else
  SED_CMD="sed -i"
fi

$SED_CMD "s/PROJECT_NAME/$PROJECT_NAME/g" package.json
$SED_CMD "s/PROJECT_NAME/$PROJECT_NAME/g" plans/prd.json
$SED_CMD "s/\[Project Name\]/$PROJECT_NAME/g" CLAUDE.md

# Install dependencies
bun install

# Set up husky
bunx husky init
cat > .husky/pre-commit << 'EOF'
bunx lint-staged
bun run typecheck
bun run test
EOF

# Set permissions
chmod +x plans/ralph.sh
chmod +x .claude/hooks/block-dangerous-git.sh

# Initialise git
rm -rf .git
git init
git add -A
git commit -m "chore: scaffold $PROJECT_NAME via ralph-greenfield"
git checkout -b ralph/initial-build

echo ""
echo "Done. Next steps:"
echo "  1. Edit plans/prd.json with your user stories"
echo "  2. Run ./plans/ralph.sh 20"
