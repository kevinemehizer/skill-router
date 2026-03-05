# Skill Router for Claude Code

On-demand capability loading for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Keep 100+ skills, commands, agents, and plugins installed without paying the token cost — the router loads only what you need, when you need it.

> **Note:** This is built specifically for Claude Code (Anthropic's CLI/Desktop app). It uses Claude Code's skill system, commands, plugins, and MCP integrations. It does not work with ChatGPT, Cursor, or other AI tools.

![Skill Router Architecture](diagram.png)

## The Problem

Every enabled skill in Claude Code loads its full description into every session's context window. With 10+ skills, that's thousands of tokens consumed before you even ask a question. But disabling skills makes them invisible — Claude won't know they exist.

## The Solution

The skill-router sits in every session (~150 tokens) and knows about everything you have installed. When you ask for something specialized, it:

1. Searches a lightweight TSV registry of all your capabilities
2. Matches your intent against **trigger phrases** — natural-language descriptions of when to use each skill
3. Reads the matched skill's instructions and follows them on the fly

Disabled skills work as if they were enabled. Zero cost until invoked.

## Smart Triggers

The router uses **trigger phrases** as its primary matching signal — not just keywords or names.

When you rebuild the registry, the router auto-generates intent-aware trigger phrases for every installed skill by analyzing each skill's description. These phrases match how you'd naturally ask for help:

| You say | Trigger matches | Skill loaded |
|---------|----------------|--------------|
| "Help me with SEO" | `improve SEO, comprehensive seo analysis` | `seo` |
| "Write copy for my landing page" | `write, rewrite, or improve marketing copy` | `copywriting` |
| "Audit my Google Ads" | `google ads deep analysis` | `ads-google` |
| "Optimize my signup flow" | `optimize signup, registration, account creation` | `signup-flow-cro` |

### How triggers are generated

1. **Manual override** — Add a `trigger:` field to your skill's YAML frontmatter for perfect control
2. **Auto-generated** — If no manual trigger exists, the rebuild script analyzes the skill's full description and generates trigger phrases automatically

### Manual trigger example

Add `trigger:` to any skill's `SKILL.md` frontmatter:

```yaml
---
name: seo
description: Comprehensive SEO analysis for any website or business type.
trigger: audit website SEO, fix search rankings, technical SEO check, optimize metadata
---
```

The router will use your manual trigger verbatim instead of auto-generating one.

## What It Routes

| Type | How It Activates |
|------|-----------------|
| Disabled skill | Reads its SKILL.md, follows instructions directly |
| Enabled skill | Invokes via Skill tool normally |
| Disabled command | Reads its .md file, follows instructions |
| Enabled command | Reads its .md file, follows instructions |
| Disabled plugin | Tells you to enable it (can't hot-load MCP tools) |
| Enabled plugin | Uses tools directly |
| Disabled agent | Reads config, spawns agent |
| Superpowers sub-skill | Invokes via Skill tool |

## Install

```bash
git clone https://github.com/kevinemehizer/skill-router.git
cd skill-router
bash install.sh
```

The install script will:
- Copy the skill-router to `~/.claude/skills/skill-router/`
- Scan your installed capabilities and generate the registry with auto-triggers
- Add a routing instruction to your `~/.claude/CLAUDE.md`

Then restart Claude Code.

## Setup

After installing, move rarely-used skills to the disabled folder:

```bash
# Example: move a skill you don't use every session
mv ~/.claude/skills/some-skill ~/.claude/skills-disabled/some-skill

# Rebuild the registry to pick up the change
bash ~/.claude/skills/skill-router/scripts/rebuild-registry.sh
```

**Keep enabled** (always loaded):
- `skill-router` — the router itself
- `mcp-client` — if you use MCP servers
- `dev-core` — if you use it for development orchestration
- Any skill you use in nearly every session

**Move to disabled** (loaded on demand):
- Everything else

## Usage

Just talk naturally. The router triggers automatically when your request matches a specialized domain.

```
"Help me with SEO"              → loads seo skill
"Write copy for my landing page" → loads copywriting skill
"Create a Remotion video"        → loads remotion skill
"What can you do?"               → shows all categories
"Audit my Google Ads"            → loads ads-google skill
```

## Rebuild the Registry

After adding, removing, or moving skills:

```bash
bash ~/.claude/skills/skill-router/scripts/rebuild-registry.sh
```

The script scans:
- `~/.claude/skills/` (enabled skills)
- `~/.claude/skills-disabled/` (disabled skills)
- `~/.claude/commands/` (enabled commands)
- `~/.claude/commands-disabled/` (disabled commands)
- `~/.claude/agents-disabled/` (disabled agents)
- `~/.claude/settings.json` (plugins)
- Superpowers sub-skills (hardcoded list)

Then auto-generates trigger phrases for every entry.

## How It Works

```
~/.claude/skills/skill-router/
├── SKILL.md                        # Router logic + activation protocol
├── scripts/
│   ├── rebuild-registry.sh         # Generates the registry
│   └── generate-triggers.py        # Auto-generates trigger phrases
└── references/
    └── registry.tsv                # Generated index (not committed)
```

The registry is a tab-separated file with one row per capability:

```
NAME    TYPE    CATEGORY    STATUS    PATH    KEYWORDS    TRIGGER    DESCRIPTION
seo     skill   seo         disabled  ...     seo,audit   comprehensive seo analysis, improve SEO    Full SEO analysis
```

**Matching priority:**
1. **TRIGGER** — intent phrases (primary signal)
2. **NAME** — exact skill name
3. **KEYWORDS** — extracted terms
4. **CATEGORY / DESCRIPTION** — broad fallback

## Important: What the Router Can and Can't Do

The router makes **disabled skills and commands** work seamlessly on demand — Claude reads their instructions and follows them as if they were enabled. No restart needed.

However, **disabled plugins and connectors are different.** Plugins provide MCP tools that must be loaded when Claude Code starts. The router **cannot** enable a disabled plugin mid-session. Here's what happens:

| Capability Type | Can the router load it on demand? |
|----------------|----------------------------------|
| Skills (enabled or disabled) | **Yes** — reads SKILL.md and follows it |
| Commands (enabled or disabled) | **Yes** — reads the .md file and follows it |
| Agents (disabled) | **Yes** — reads config and spawns agent |
| Superpowers sub-skills | **Yes** — invokes via Skill tool |
| **Plugins / Connectors (disabled)** | **No** — tells you which plugin to enable, then you restart |

If you're using the **Claude Code Desktop app** and have connectors/plugins disabled, the router will tell you exactly which one to turn on — but you'll need to enable it in settings and restart the app yourself. This is a platform limitation, not a router limitation.

**Tip:** If you frequently need a specific plugin, just keep it enabled. The token savings from the router come primarily from skills and commands (which make up the vast majority of capabilities), not plugins.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI or Desktop app
- Bash (macOS/Linux)
- Python 3 (for trigger generation and plugin detection)

## License

MIT
