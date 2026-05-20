# Knowledge Base Guide

You have access to a project knowledge base (KB) plugin. Use it to track and document project knowledge.

## Available Tools

| Tool | Purpose |
|------|---------|
| `KBInit` | Initialize the KB directory structure (safe to call multiple times) |
| `KBLog` | Log a new entry — AI classifies and structures it automatically |
| `KBQuery` | Search the KB by keyword (titles, tags, content) |
| `KBList` | List entries, optionally filtered by category/status/tag |
| `KBGet` | Get full content of an entry by ID (e.g. F-001) |
| `KBUpdate` | Update metadata or content of an existing entry |
| `KBDelete` | Permanently delete an entry |
| `KBExport` | Generate index.md or full consolidated export |

## Categories

| Category | Prefix | Use for |
|----------|--------|---------|
| `feature` | F-NNN | User-facing functionality, capabilities, behaviors |
| `decision` | D-NNN | Technical choices, trade-offs, ADRs |
| `architecture` | A-NNN | System design, components, data flow, infrastructure |
| `sprint` | S-NNN | Sprint goals, retrospectives, iteration summaries |
| `note` | N-NNN | General learnings, research, observations |

## Status Lifecycle

`planned` → `in-progress` → `done` (or `deprecated`)

## Workflow

1. **Before logging**: Always `KBQuery` first to check for existing entries
2. **Log knowledge**: Use `KBLog` with freeform text — AI classifies and structures it
3. **Override classification**: Pass `category`, `title`, `status`, `tags`, `priority` to override AI
4. **Update entries**: Use `KBUpdate` to change status, append notes, or rewrite content
5. **Generate docs**: Use `KBExport` with format "index" or "full"

## When to Log

- A technical decision is made → `KBLog` as decision (ADR format)
- A new feature is planned or started → `KBLog` as feature
- System architecture is designed or changed → `KBLog` as architecture
- A sprint begins or ends → `KBLog` as sprint
- Something interesting is learned → `KBLog` as note

## Entry Format

Each entry is a markdown file with YAML frontmatter:

```markdown
---
id: F-001
title: User Authentication
category: feature
status: in-progress
tags: auth, security
priority: high
created: 2026-05-19
updated: 2026-05-19
---

# User Authentication

## Description
...
```

## Tips

- Use 2-5 descriptive lowercase tags per entry
- Keep titles under 80 characters
- Reference related entries by ID in the body (e.g. "See D-003")
- For decisions, always include context, the decision, and consequences
- For features, include acceptance criteria when possible
- Run `KBExport` with format "full" to generate complete project documentation
