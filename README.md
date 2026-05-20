# claudio-kb

A project knowledge base plugin for [Claudio](https://github.com/Abraxas-365/claudio). Tracks features, decisions, architecture, sprints, and notes as structured markdown files with AI-powered classification.

## Install

Add to your `~/.claudio/init.lua` or `.claudio/init.lua`:

```lua
claudio.plugin.use({
  source = "Abraxas-365/claudio-kb",
  config = function()
    require("claudio-kb").setup({
      -- base_path = "kb",                          -- default: kb/ in project root
      -- ai_model  = "claude-haiku-4-5-20251001",   -- model for classification
      -- use_ai    = true,                           -- set false to disable AI
    })
  end,
})
```

Then run `:PluginSync` to install.

## What it does

When you tell Claudio about a feature, decision, or architectural choice, it:

1. **Classifies** the input (feature / decision / architecture / sprint / note)
2. **Structures** it into well-formatted markdown (ADR-style for decisions, specs for features, etc.)
3. **Saves** it to `kb/<category>/` with auto-generated ID and frontmatter
4. **Indexes** all entries in `kb/index.md`

All files are plain markdown — readable, git-friendly, and useful beyond Claudio.

## Tools

| Tool | Description |
|------|-------------|
| `KBInit` | Initialize KB directory structure |
| `KBLog` | Log new entry (AI classifies and structures) |
| `KBQuery` | Search the knowledge base |
| `KBList` | List entries (filter by category/status/tag) |
| `KBGet` | Get full content of an entry by ID |
| `KBUpdate` | Update existing entry |
| `KBDelete` | Delete an entry |
| `KBExport` | Generate index or full export |

## Categories

| Category | ID Prefix | Template |
|----------|-----------|----------|
| Feature | F-NNN | Description, acceptance criteria, technical notes |
| Decision | D-NNN | ADR: context, decision, consequences, alternatives |
| Architecture | A-NNN | Overview, components, data flow, dependencies |
| Sprint | S-NNN | Goal, completed, retrospective |
| Note | N-NNN | Freeform |

## Agent

The plugin registers a **documenter** agent — a technical writer persona that manages the knowledge base. Invoke it via `@documenter` or the agent picker.

## Directory structure

```
kb/
├── index.md           # Auto-generated summary
├── feature/
│   ├── f-001-user-auth.md
│   └── f-002-search.md
├── decision/
│   └── d-001-chose-sqlite.md
├── architecture/
│   └── a-001-event-bus.md
├── sprint/
│   └── s-001-week-20.md
└── note/
    └── n-001-performance-findings.md
```

## Configuration

```lua
require("claudio-kb").setup({
  base_path = "docs/kb",                     -- custom path (default: "kb")
  ai_model  = "claude-haiku-4-5-20251001",   -- model for classification
  use_ai    = false,                          -- disable AI, use templates only
})
```

## Examples

```
> We decided to use WebSockets instead of SSE for real-time updates because we need
> bidirectional communication for the collaborative editing feature. SSE would have
> required a separate endpoint for client-to-server messages.

# AI automatically:
# - Classifies as "decision"
# - Generates ADR with context, decision, consequences
# - Saves to kb/decision/d-001-websockets-over-sse.md
# - Updates kb/index.md
```

## License

MIT
