---
name: skill-router
description: On-demand capability router for 120+ skills, commands, agents, and plugins across SEO, advertising, CRO, copywriting, email, content strategy, marketing, branding, analytics, product management, design, video, documents, deployment, database, scraping, testing, security, and development. Use when the user's request matches a specialized domain outside general coding — e.g. "help with SEO", "write ad copy", "create a lead magnet", "audit my landing page", "build a Remotion video", "sync Figma", "run ads analysis", or "what can you do". Also triggers on /commands that aren't currently loaded.
---

# Skill Router

Route user requests to the best matching capability from the full registry of disabled and enabled skills, commands, agents, plugins, and superpowers sub-skills.

## Skill Location

This skill is located at: `~/.claude/skills/skill-router/`

## When This Skill Triggers

- User asks about a specialized domain (SEO, ads, CRO, copywriting, email, marketing, etc.)
- User says "what can you do" or asks about capabilities
- User references a skill/command that isn't currently loaded
- User asks for something that sounds like a marketing, growth, content, or business task

## Lookup Protocol

1. **Read the registry**: Use the Read tool to load `~/.claude/skills/skill-router/references/registry.tsv`
2. **Search for matches**: Scan NAME, CATEGORY, KEYWORDS, and DESCRIPTION columns for the best match to the user's request
3. **If multiple matches**: Prefer the most specific match. If still ambiguous, list the top 3 options and ask the user to pick.
4. **Activate the match** using the rules below

## Activation Rules by Type

### Disabled Skill (`TYPE=skill`, `STATUS=disabled`)
1. Read the SKILL.md file at the PATH column (e.g., `~/.claude/skills-disabled/seo/SKILL.md`)
2. Follow those instructions as if they were loaded normally
3. The skill's `references/` and `scripts/` directories are available at the same path

### Enabled Skill (`TYPE=skill`, `STATUS=enabled`)
1. Invoke via the Skill tool: `Skill("name")`

### Disabled Command (`TYPE=command`, `STATUS=disabled`)
1. Read the .md file at the PATH column (e.g., `~/.claude/commands-disabled/brand-voice.md`)
2. Follow those instructions as if they were a loaded command

### Enabled Command (`TYPE=command`, `STATUS=enabled`)
1. Read the .md file at the PATH column (e.g., `~/.claude/commands/code-architect.md`)
2. Follow those instructions

### Disabled Plugin (`TYPE=plugin`, `STATUS=disabled`)
1. Tell the user: "The **[name]** plugin needs to be enabled. Run `/plugins` or update `~/.claude/settings.json` to set `"[plugin_id]": true`, then restart Claude Code."
2. Do NOT attempt to use the plugin's MCP tools — they won't be available

### Enabled Plugin (`TYPE=plugin`, `STATUS=enabled`)
1. The plugin's tools are already available — use them directly

### Disabled Agent (`TYPE=agent`, `STATUS=disabled`)
1. Read the .md file at the PATH column
2. Use it as agent configuration when spawning an Agent tool subagent

### Superpowers Sub-skill (`TYPE=superpowers`)
1. Invoke via: `Skill("superpowers:name")`

### MCP Server (not in registry — delegate)
1. If the request is about an MCP server, delegate to the `mcp-client` skill: `Skill("mcp-client")`

## "What Can You Do?" Response

When the user asks about capabilities, summarize by category:

| Category | Examples |
|----------|----------|
| SEO | Site audits, page analysis, schema markup, content optimization, sitemaps |
| Advertising | Google/Meta/LinkedIn/TikTok/YouTube/Microsoft ads, audits, budgets, creative |
| CRO | Landing pages, forms, popups, onboarding, paywalls, signup flows |
| Content | Copywriting, copy editing, blog posts, social content, content repurposing |
| Email | Email sequences, newsletters |
| Marketing | Growth strategy, launch plans, referrals, pricing, free tools, psychology |
| Branding | Brand voice, ideal customer personas |
| Product | PRDs, product announcements, product marketing, product management |
| Design | Web design review, Figma sync, wireframes, frontend design |
| Video | Remotion video creation and editing |
| Development | Code architecture, code review, debugging, TDD, React/Next.js patterns |
| QA | Epic testing, browser automation |
| Analytics | A/B testing, tracking setup |
| Documents | Presentations (PPTX), SOPs |
| Integrations | GitHub, Vercel, Supabase, Figma, Playwright, and more via plugins |

Say: "Ask me about any of these — I'll load the right specialist on demand."

## Rebuilding the Registry

If skills are added or removed, regenerate:
```bash
bash ~/.claude/skills/skill-router/scripts/rebuild-registry.sh
```

## Fallback

If no match is found in the registry:
1. Check if the `find-skills` skill exists in `skills-disabled/` and load it to search for external skills
2. Otherwise, tell the user no matching capability was found and suggest they describe their goal differently
