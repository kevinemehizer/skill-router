#!/usr/bin/env python3
"""
Add TRIGGER column to the skill-router registry TSV.

For each registry entry:
  1. Read source file for manual 'trigger:' frontmatter field (user override)
  2. Read full description from source file for better generation
  3. Auto-generate trigger phrases from name + full description + category
  4. Insert TRIGGER column into the TSV

Usage: python3 generate-triggers.py <registry.tsv>
"""

import os
import sys
import re


def expand_path(p):
    """Expand ~ to home directory."""
    return os.path.expanduser(p)


def read_file(filepath):
    """Read file contents, return None if missing."""
    filepath = expand_path(filepath)
    if not os.path.isfile(filepath):
        return None
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except Exception:
        return None


def extract_frontmatter(content):
    """Extract YAML frontmatter fields from markdown content."""
    if not content:
        return {}
    m = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
    if not m:
        return {}

    result = {}
    current_key = None
    current_value_lines = []

    for line in m.group(1).split('\n'):
        # New key: value pair
        km = re.match(r'^(\w[\w-]*):\s*(.*)', line)
        if km:
            if current_key:
                result[current_key] = ' '.join(current_value_lines).strip()
            current_key = km.group(1)
            value = km.group(2).strip()
            if value in ('>', '|', '>-', '|-'):
                current_value_lines = []
            else:
                current_value_lines = [value.strip('"').strip("'")]
        elif current_key and (line.startswith('  ') or line.startswith('\t')):
            current_value_lines.append(line.strip())
        elif current_key and line.strip() == '':
            # Blank line inside block scalar — continue
            pass
        else:
            if current_key:
                result[current_key] = ' '.join(current_value_lines).strip()
                current_key = None
                current_value_lines = []

    if current_key:
        result[current_key] = ' '.join(current_value_lines).strip()

    return result


def get_source_file(path, entry_type):
    """Find the source markdown file for a registry entry."""
    path = expand_path(path)
    if entry_type == 'skill':
        candidate = os.path.join(path, 'SKILL.md')
        if os.path.isfile(candidate):
            return candidate
    elif entry_type in ('command', 'agent'):
        if os.path.isfile(path):
            return path
    return None


def generate_trigger(name, description, category):
    """Auto-generate trigger phrases from skill metadata.

    Produces 2-5 comma-separated imperative phrases that match
    how a user would naturally ask for this capability.
    """
    triggers = []
    name_phrase = name.replace('-', ' ').replace(':', ' ').strip()

    # Normalize empty/malformed descriptions
    if not description or description.strip() in ('', '|'):
        return name_phrase

    desc = description.strip()

    # --- Pattern 1: "When the user wants to X. Also use when..." ---
    m = re.match(
        r'When the user wants to (.+?)(?:\.\s*Also|\.\s*$|$)',
        desc, re.IGNORECASE
    )
    if m:
        action = m.group(1).strip().rstrip('.,')
        triggers.append(action)

        # Extract quoted terms from "Also use when the user mentions 'X', 'Y'"
        # These are excellent natural-language triggers
        also_terms = re.findall(
            r'[\u2018\u2019\u201c\u201d\'"]([^\u2018\u2019\u201c\u201d\'"]{2,40})[\u2018\u2019\u201c\u201d\'"]',
            desc
        )
        for term in also_terms[:3]:
            t = term.lower().strip().rstrip('.,;:!?')
            if t and len(t) > 2 and t not in [x.lower() for x in triggers]:
                triggers.append(t)
    else:
        # --- Pattern 2: Descriptive phrase (not "When the user...") ---
        first_sentence = re.split(r'\.\s', desc)[0].strip().rstrip('.')
        if len(first_sentence) > 5:
            triggers.append(first_sentence.lower())

    # Add name as phrase if not already covered
    name_lower = name_phrase.lower()
    if not any(name_lower in t.lower() for t in triggers):
        triggers.append(name_phrase)

    # Category augmentation for discoverability
    CAT_PHRASES = {
        'seo': 'improve SEO',
        'advertising': 'optimize ads',
        'cro': 'improve conversions',
        'content': 'create content',
        'email': 'email campaign',
        'marketing': 'marketing strategy',
        'copywriting': 'write copy',
        'branding': 'brand identity',
        'design': 'design review',
        'development': 'code help',
        'testing': 'run tests',
        'documents': 'create document',
        'analytics': 'track analytics',
        'competitive': 'competitor analysis',
    }
    cat_phrase = CAT_PHRASES.get(category)
    if cat_phrase and not any(cat_phrase.lower() in t.lower() for t in triggers):
        triggers.append(cat_phrase)

    # Deduplicate and limit
    seen = set()
    unique = []
    for t in triggers:
        key = t.lower().strip()
        if key and key not in seen and len(key) > 2:
            seen.add(key)
            unique.append(key)

    return ', '.join(unique[:5])


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate-triggers.py <registry.tsv>", file=sys.stderr)
        sys.exit(1)

    tsv_path = sys.argv[1]

    with open(tsv_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    if not lines:
        return

    header = lines[0].rstrip('\n').split('\t')

    # Don't double-add
    if 'TRIGGER' in header:
        print("  TRIGGER column already present — skipping", file=sys.stderr)
        return

    # Insert TRIGGER after KEYWORDS, before DESCRIPTION
    try:
        kw_idx = header.index('KEYWORDS')
    except ValueError:
        kw_idx = len(header) - 2

    new_header = header[:kw_idx + 1] + ['TRIGGER'] + header[kw_idx + 1:]
    new_lines = ['\t'.join(new_header) + '\n']
    count = 0

    for line in lines[1:]:
        line = line.rstrip('\n')
        if not line.strip():
            continue

        fields = line.split('\t')
        # Pad short rows
        while len(fields) < len(header):
            fields.append('')

        name = fields[0]
        entry_type = fields[1]
        category = fields[2]
        path = fields[4]
        tsv_desc = fields[6] if len(fields) > 6 else ''

        # Try to read source file for manual trigger and full description
        trigger = None
        source_file = get_source_file(path, entry_type)
        full_desc = tsv_desc

        if source_file:
            content = read_file(source_file)
            fm = extract_frontmatter(content)
            # Manual trigger override
            trigger = fm.get('trigger', '').strip()
            # Full description (not truncated) for better generation
            if fm.get('description'):
                full_desc = fm['description']

        if not trigger:
            trigger = generate_trigger(name, full_desc or tsv_desc, category)

        new_fields = fields[:kw_idx + 1] + [trigger] + fields[kw_idx + 1:]
        new_lines.append('\t'.join(new_fields) + '\n')
        count += 1

    with open(tsv_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"  Added TRIGGER column ({count} entries)", file=sys.stderr)


if __name__ == '__main__':
    main()
