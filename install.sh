#!/usr/bin/env bash
# install.sh — Install the skill-router into your Claude Code setup
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/skills/skill-router"

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing skill-router..."

# 1. Create skills-disabled if it doesn't exist
mkdir -p "$CLAUDE_DIR/skills-disabled"

# 2. Copy skill-router to skills/
if [ -d "$DEST" ]; then
  echo "  skill-router already exists at $DEST — updating files..."
fi
mkdir -p "$DEST/scripts" "$DEST/references"
cp "$SCRIPT_DIR/skill-router/SKILL.md" "$DEST/SKILL.md"
cp "$SCRIPT_DIR/skill-router/scripts/rebuild-registry.sh" "$DEST/scripts/rebuild-registry.sh"
cp "$SCRIPT_DIR/skill-router/scripts/generate-triggers.py" "$DEST/scripts/generate-triggers.py"
chmod +x "$DEST/scripts/rebuild-registry.sh"

# 3. Generate the registry
echo "  Generating registry..."
bash "$DEST/scripts/rebuild-registry.sh"

# 4. Add routing instruction to CLAUDE.md if not already present
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if ! grep -q "skill-router" "$CLAUDE_MD" 2>/dev/null; then
    echo "" >> "$CLAUDE_MD"
    echo "## Capability Routing" >> "$CLAUDE_MD"
    echo "For specialized tasks outside general coding, invoke the skill-router skill first." >> "$CLAUDE_MD"
    echo "  Added routing instruction to $CLAUDE_MD"
  else
    echo "  Routing instruction already in $CLAUDE_MD — skipping"
  fi
else
  echo "# Global Instructions" > "$CLAUDE_MD"
  echo "" >> "$CLAUDE_MD"
  echo "## Capability Routing" >> "$CLAUDE_MD"
  echo "For specialized tasks outside general coding, invoke the skill-router skill first." >> "$CLAUDE_MD"
  echo "  Created $CLAUDE_MD with routing instruction"
fi

echo ""
echo "Done! skill-router installed."
echo ""
echo "Next steps:"
echo "  1. Move rarely-used skills from ~/.claude/skills/ to ~/.claude/skills-disabled/"
echo "  2. Restart Claude Code to pick up the new skill"
echo "  3. Try: \"What can you do?\" or \"Help me with SEO\""
echo ""
echo "To rebuild the registry after adding/removing capabilities:"
echo "  bash ~/.claude/skills/skill-router/scripts/rebuild-registry.sh"
