#!/usr/bin/env bash
# rebuild-registry.sh - Scans all capability sources and generates registry.tsv
# Usage: bash ~/.claude/skills/skill-router/scripts/rebuild-registry.sh

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
OUT="$CLAUDE_DIR/skills/skill-router/references/registry.tsv"

mkdir -p "$(dirname "$OUT")"

# Helper: extract frontmatter field from a markdown file
# Usage: extract_field <file> <field>
extract_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/ { block++; next }
    block == 1 && $0 ~ "^"f":" {
      val = $0
      sub("^"f": *>?-? *", "", val)
      gsub(/^["'"'"']|["'"'"']$/, "", val)
      if (val != "") { print val; exit }
      # Multi-line: collect indented continuation lines
      while ((getline) > 0) {
        if (/^---$/) exit
        if (/^[^ \t]/) exit
        gsub(/^[ \t]+/, "")
        if ($0 != "") { print; exit }
      }
    }
  ' "$file" 2>/dev/null
}

# Helper: extract keywords from name and description
# Takes name and description, outputs comma-separated keywords
make_keywords() {
  local name="$1" desc="$2"
  local kw
  kw=$(echo "$name" | tr '-' ',')
  local desc_words
  desc_words=$(echo "$desc" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | \
    sed '/^$/d' | \
    grep -vE '^(the|a|an|and|or|for|to|of|in|on|is|use|this|when|with|any|that|from|it|by|as|all)$' | \
    head -8 | tr '\n' ',' | sed 's/,$//') || true
  if [ -n "$desc_words" ]; then
    kw="$kw,$desc_words"
  fi
  echo "$kw"
}

# Truncate description to max length for TSV compactness
truncate_desc() {
  echo "$1" | head -1 | cut -c1-120
}

# Write header
echo -e "NAME\tTYPE\tCATEGORY\tSTATUS\tPATH\tKEYWORDS\tDESCRIPTION" > "$OUT"

# --- 1. Disabled skills ---
if [ -d "$CLAUDE_DIR/skills-disabled" ]; then
  for entry in "$CLAUDE_DIR/skills-disabled"/*/; do
    [ -d "$entry" ] || continue
    name=$(basename "$entry")
    skill_file="$entry/SKILL.md"
    [ -f "$skill_file" ] || continue
    desc=$(extract_field "$skill_file" "description")
    [ -z "$desc" ] && desc="$name skill"
    # Infer category from name prefix or parent skill
    category="general"
    case "$name" in
      seo*) category="seo" ;;
      ads*) category="advertising" ;;
      *-cro|form-cro|page-cro|popup-cro|onboarding-cro|paywall-upgrade-cro|signup-flow-cro) category="cro" ;;
      copywriting|copy-editing|brand-voice*|social-content|content-strategy) category="content" ;;
      email-*) category="email" ;;
      marketing-*|launch-strategy|free-tool-strategy|referral-program|pricing-strategy) category="marketing" ;;
      product-*) category="product" ;;
      programmatic-seo) category="seo" ;;
      schema-markup) category="seo" ;;
      pptx-generator|sop-creator) category="documents" ;;
      figma-sync) category="design" ;;
      agent-browser) category="testing" ;;
      analytics-tracking|ab-test-setup) category="analytics" ;;
      competitor-*) category="competitive" ;;
      vercel-*) category="development" ;;
      paid-ads) category="advertising" ;;
      build-ready|qa-ready|full-pipeline) category="devops" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tskill\t${category}\tdisabled\t~/.claude/skills-disabled/${name}\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# Disabled skills that are symlinks (not directories with subdirs)
if [ -d "$CLAUDE_DIR/skills-disabled" ]; then
  for entry in "$CLAUDE_DIR/skills-disabled"/*; do
    [ -L "$entry" ] || continue
    [ -d "$entry" ] || continue
    name=$(basename "$entry")
    skill_file="$entry/SKILL.md"
    [ -f "$skill_file" ] || continue
    # Skip if already processed
    grep -q "^${name}	" "$OUT" 2>/dev/null && continue
    desc=$(extract_field "$skill_file" "description")
    [ -z "$desc" ] && desc="$name skill"
    category="general"
    case "$name" in
      seo*) category="seo" ;;
      ads*) category="advertising" ;;
      *-cro) category="cro" ;;
      copywriting|copy-editing|brand-voice*|social-content|content-strategy) category="content" ;;
      email-*) category="email" ;;
      marketing-*|launch-strategy|free-tool-strategy|referral-program|pricing-strategy) category="marketing" ;;
      product-*) category="product" ;;
      schema-markup|programmatic-seo) category="seo" ;;
      pptx-generator|sop-creator) category="documents" ;;
      figma-sync) category="design" ;;
      agent-browser) category="testing" ;;
      analytics-tracking|ab-test-setup) category="analytics" ;;
      competitor-*) category="competitive" ;;
      vercel-*) category="development" ;;
      paid-ads) category="advertising" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tskill\t${category}\tdisabled\t~/.claude/skills-disabled/${name}\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 2. Enabled skills (except always-on: skill-router, mcp-client, dev-core) ---
if [ -d "$CLAUDE_DIR/skills" ]; then
  for entry in "$CLAUDE_DIR/skills"/*/; do
    [ -d "$entry" ] || continue
    name=$(basename "$entry")
    # Skip always-enabled skills
    case "$name" in
      skill-router|mcp-client|dev-core) continue ;;
    esac
    skill_file="$entry/SKILL.md"
    [ -f "$skill_file" ] || continue
    desc=$(extract_field "$skill_file" "description")
    [ -z "$desc" ] && desc="$name skill"
    category="general"
    case "$name" in
      seo*) category="seo" ;;
      ads*) category="advertising" ;;
      *-cro) category="cro" ;;
      find-skills) category="meta" ;;
      web-design-guidelines) category="design" ;;
      remotion) category="video" ;;
      skill-creator) category="meta" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tskill\t${category}\tenabled\t~/.claude/skills/${name}\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 3. Enabled commands ---
if [ -d "$CLAUDE_DIR/commands" ]; then
  for f in "$CLAUDE_DIR/commands"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(extract_field "$f" "description")
    [ -z "$desc" ] && desc="$name command"
    category="development"
    case "$name" in
      code-*|senior-frontend*) category="development" ;;
      lite-prd*|ux-spec*) category="product" ;;
      *wireframe*|lofi-*|screenshot-*) category="design" ;;
      qa-*|epic-*) category="qa" ;;
      project-status|continuation-prompt) category="meta" ;;
      skill-creator) category="meta" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tcommand\t${category}\tenabled\t~/.claude/commands/${name}.md\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 4. Disabled commands ---
if [ -d "$CLAUDE_DIR/commands-disabled" ]; then
  for f in "$CLAUDE_DIR/commands-disabled"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(extract_field "$f" "description")
    [ -z "$desc" ] && desc="$name command"
    category="content"
    case "$name" in
      brand-voice|ideal-customer-persona) category="branding" ;;
      content-repurposer|long-form-blog-post|topic-refiner) category="content" ;;
      email-newsletter) category="email" ;;
      growth-lead) category="marketing" ;;
      landing-page-copy|sales-page-optimization|lead-magnet) category="copywriting" ;;
      product-announcement-bundle) category="product" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tcommand\t${category}\tdisabled\t~/.claude/commands-disabled/${name}.md\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 5. Disabled agents ---
if [ -d "$CLAUDE_DIR/agents-disabled" ]; then
  for f in "$CLAUDE_DIR/agents-disabled"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    desc=$(extract_field "$f" "description")
    [ -z "$desc" ] && desc="$name agent"
    category="general"
    case "$name" in
      seo-*) category="seo" ;;
      audit-*) category="advertising" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tagent\t${category}\tdisabled\t~/.claude/agents-disabled/${name}.md\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 6. Plugins ---
# Read from settings.json
settings="$CLAUDE_DIR/settings.json"
if [ -f "$settings" ]; then
  python3 -c "
import json, sys
with open('$settings') as f:
    data = json.load(f)
plugins = data.get('enabledPlugins', {})
for plugin_id, enabled in plugins.items():
    name = plugin_id.split('@')[0]
    status = 'enabled' if enabled else 'disabled'
    print(f'{name}\t{plugin_id}\t{status}')
" 2>/dev/null | while IFS=$'\t' read -r name plugin_id status; do
    # Skip always-on (handled elsewhere)
    case "$name" in
      superpowers|claude-mem|claude-code-setup) continue ;;
    esac
    category="integration"
    case "$name" in
      playwright) category="testing"; desc="Browser automation and E2E testing" ;;
      firecrawl) category="scraping"; desc="Web scraping and crawling" ;;
      context7) category="development"; desc="Context management for coding" ;;
      vercel) category="deployment"; desc="Vercel deployment and hosting" ;;
      gitlab) category="development"; desc="GitLab integration" ;;
      figma) category="design"; desc="Figma design integration" ;;
      github) category="development"; desc="GitHub integration" ;;
      supabase) category="database"; desc="Supabase backend and database" ;;
      frontend-design) category="design"; desc="Frontend design generation" ;;
      skill-creator) category="meta"; desc="Skill creation plugin" ;;
      playground) category="development"; desc="Interactive playground creation" ;;
      security-guidance) category="security"; desc="Security best practices guidance" ;;
      *) desc="$name plugin" ;;
    esac
    keywords=$(make_keywords "$name" "$desc")
    short_desc=$(truncate_desc "$desc")
    echo -e "${name}\tplugin\t${category}\t${status}\t${plugin_id}\t${keywords}\t${short_desc}" >> "$OUT"
  done
fi

# --- 7. Superpowers sub-skills ---
for sp in writing-plans systematic-debugging test-driven-development verification-before-completion brainstorming requesting-code-review dispatching-parallel-agents; do
  category="development"
  case "$sp" in
    writing-plans) desc="Plan and structure implementation approaches" ;;
    systematic-debugging) desc="Methodical debugging with hypothesis testing" ;;
    test-driven-development) desc="Write tests first, then implement" ;;
    verification-before-completion) desc="Verify work before claiming done" ;;
    brainstorming) desc="Creative ideation and exploration" ;;
    requesting-code-review) desc="Structured code review process" ;;
    dispatching-parallel-agents) desc="Run multiple agents in parallel" ;;
  esac
  keywords=$(make_keywords "$sp" "$desc")
  short_desc=$(truncate_desc "$desc")
  echo -e "superpowers:${sp}\tsuperpowers\t${category}\tenabled\tsuperpowers:${sp}\t${keywords}\t${short_desc}" >> "$OUT"
done

# --- 8. Generate trigger phrases ---
# Reads each skill's source file for manual trigger: overrides,
# auto-generates triggers from descriptions for the rest
TRIGGER_SCRIPT="$CLAUDE_DIR/skills/skill-router/scripts/generate-triggers.py"
if [ -f "$TRIGGER_SCRIPT" ]; then
  python3 "$TRIGGER_SCRIPT" "$OUT"
else
  echo "  Warning: generate-triggers.py not found — skipping trigger generation"
fi

# --- Summary ---
total=$(tail -n +2 "$OUT" | wc -l | tr -d ' ')
echo "Registry rebuilt: $OUT ($total entries)"
