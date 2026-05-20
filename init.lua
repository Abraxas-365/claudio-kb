-- claudio-kb — Project Knowledge Base plugin for Claudio
-- Tracks features, decisions, architecture, sprints, and notes.
-- Stores entries as structured markdown with AI-powered classification.
--
-- Install in .claudio/init.lua:
--   claudio.plugin.use({
--     source = "Abraxas-365/claudio-kb",
--     config = function()
--       require("claudio-kb").setup({ base_path = "kb" })
--     end,
--   })

local plugin_dir = PLUGIN_DIR or "."

-- ── Module loader ─────────────────────────────────────────────────────────────

package.path = package.path
  .. ";" .. plugin_dir .. "/lib/?.lua"

local storage   = require("storage")
local templates = require("templates")
local ai_mod    = require("ai")
local index     = require("index")

-- ── Config ────────────────────────────────────────────────────────────────────

local _config = {
  base_path = nil,          -- nil = auto-detect (cwd/kb)
  ai_model  = "claude-haiku-4-5-20251001",
  use_ai    = true,         -- use AI for classification/structuring
}

-- ── Module ────────────────────────────────────────────────────────────────────

local M = {}

function M.setup(opts)
  opts = opts or {}
  if opts.base_path then
    _config.base_path = opts.base_path
    storage.set_base_path(opts.base_path)
  end
  if opts.ai_model then
    _config.ai_model = opts.ai_model
    ai_mod.set_model(opts.ai_model)
  end
  if opts.use_ai ~= nil then
    _config.use_ai = opts.use_ai
  end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ok(content)
  return content
end

local function err(msg)
  return claudio.json.encode({ error = msg })
end

local function ensure_init()
  if not storage.is_initialized() then
    storage.init_kb()
  end
end

local function format_entry_summary(entry)
  local meta = entry.meta
  local tags = ""
  if meta.tags and #meta.tags > 0 then
    tags = " [" .. table.concat(meta.tags, ", ") .. "]"
  end
  return string.format("%s | %-12s | %-12s | %s%s",
    meta.id or "?",
    meta.category or "?",
    meta.status or "?",
    meta.title or "Untitled",
    tags
  )
end

-- ── Tool schemas ──────────────────────────────────────────────────────────────

local KB_LOG_SCHEMA = [[{
  "type": "object",
  "properties": {
    "content": {
      "type": "string",
      "description": "Freeform description of the feature, decision, architecture note, sprint, or learning to log. The AI will classify and structure it automatically."
    },
    "category": {
      "type": "string",
      "enum": ["feature", "decision", "architecture", "sprint", "note"],
      "description": "Override auto-classification. If omitted, AI classifies automatically."
    },
    "title": {
      "type": "string",
      "description": "Override auto-generated title."
    },
    "status": {
      "type": "string",
      "enum": ["planned", "in-progress", "done", "deprecated"],
      "description": "Entry status. Default: planned."
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "description": "Tags for categorization."
    },
    "priority": {
      "type": "string",
      "enum": ["low", "medium", "high", "critical"],
      "description": "Priority level. Default: medium."
    }
  },
  "required": ["content"]
}]]

local KB_QUERY_SCHEMA = [[{
  "type": "object",
  "properties": {
    "query": {
      "type": "string",
      "description": "Search query — matches against titles, tags, and content."
    }
  },
  "required": ["query"]
}]]

local KB_LIST_SCHEMA = [[{
  "type": "object",
  "properties": {
    "category": {
      "type": "string",
      "enum": ["feature", "decision", "architecture", "sprint", "note"],
      "description": "Filter by category."
    },
    "status": {
      "type": "string",
      "enum": ["planned", "in-progress", "done", "deprecated"],
      "description": "Filter by status."
    },
    "tag": {
      "type": "string",
      "description": "Filter by tag."
    }
  }
}]]

local KB_GET_SCHEMA = [[{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Entry ID (e.g. F-001, D-002, A-001)."
    }
  },
  "required": ["id"]
}]]

local KB_UPDATE_SCHEMA = [[{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Entry ID to update (e.g. F-001)."
    },
    "content": {
      "type": "string",
      "description": "New freeform content. AI will restructure it."
    },
    "title": {"type": "string"},
    "status": {
      "type": "string",
      "enum": ["planned", "in-progress", "done", "deprecated"]
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"}
    },
    "priority": {
      "type": "string",
      "enum": ["low", "medium", "high", "critical"]
    },
    "append": {
      "type": "string",
      "description": "Text to append to the existing body instead of replacing it."
    }
  },
  "required": ["id"]
}]]

local KB_DELETE_SCHEMA = [[{
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Entry ID to delete (e.g. F-001)."
    }
  },
  "required": ["id"]
}]]

local KB_EXPORT_SCHEMA = [[{
  "type": "object",
  "properties": {
    "format": {
      "type": "string",
      "enum": ["index", "full"],
      "description": "Export format. 'index' generates index.md, 'full' generates a consolidated export. Default: index."
    }
  }
}]]

-- ── Tool: KBLog ──────────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBLog",
  description = "Log a new entry to the project knowledge base. Accepts freeform text about features, decisions, architecture, sprints, or notes. AI automatically classifies, structures, and saves it as a well-formatted markdown document. Use this whenever the team makes a decision, plans a feature, documents architecture, or wants to capture project knowledge.",
  schema      = KB_LOG_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    if not input.content or input.content == "" then
      return err("content is required")
    end

    ensure_init()

    local meta, body

    if _config.use_ai then
      -- AI-powered classification and structuring
      local classification, structured_body = ai_mod.process(input.content, {
        category = input.category,
        title    = input.title,
        status   = input.status,
        tags     = input.tags,
        priority = input.priority,
      })

      meta = {
        category = classification.category,
        title    = classification.title,
        status   = classification.status or "planned",
        tags     = classification.tags or {},
        priority = classification.priority or "medium",
      }
      body = structured_body
    else
      -- Template-based (no AI)
      local category = input.category or "note"
      local title = input.title or input.content:match("^([^\n]+)") or "Untitled"
      if #title > 80 then title = title:sub(1, 77) .. "..." end

      meta = {
        category = category,
        title    = title,
        status   = input.status or "planned",
        tags     = input.tags or {},
        priority = input.priority or "medium",
      }
      body = templates.render(category, {
        title       = title,
        description = input.content,
        content     = input.content,
      })
    end

    -- Generate ID and save
    meta.id = storage.next_id(meta.category)
    local path = storage.save_entry(meta, body)

    -- Regenerate index
    index.write(storage)

    local tags_str = ""
    if meta.tags and #meta.tags > 0 then
      tags_str = "\nTags: " .. table.concat(meta.tags, ", ")
    end

    return ok(string.format(
      "Logged %s: %s — %s\nStatus: %s | Priority: %s%s\nSaved: %s",
      meta.category, meta.id, meta.title,
      meta.status, meta.priority, tags_str,
      path
    ))
  end,
})

-- ── Tool: KBQuery ────────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBQuery",
  description = "Search the project knowledge base by keyword. Matches against titles, tags, and content. Returns relevant entries ranked by relevance. Use this to find existing knowledge before logging duplicates, or to understand project context.",
  schema      = KB_QUERY_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    if not input.query or input.query == "" then
      return err("query is required")
    end

    ensure_init()

    local results = storage.search_entries(input.query)
    if #results == 0 then
      return ok("No entries found matching: " .. input.query)
    end

    local lines = { "Found " .. #results .. " entries matching '" .. input.query .. "':", "" }
    for _, entry in ipairs(results) do
      table.insert(lines, format_entry_summary(entry))
    end

    -- Include full body of top 3 results
    table.insert(lines, "")
    table.insert(lines, "--- Top results (full content) ---")
    local show = math.min(3, #results)
    for i = 1, show do
      local entry = results[i]
      table.insert(lines, "")
      table.insert(lines, "### " .. (entry.meta.id or "?") .. ": " .. (entry.meta.title or "Untitled"))
      table.insert(lines, "Category: " .. (entry.meta.category or "?")
        .. " | Status: " .. (entry.meta.status or "?")
        .. " | Priority: " .. (entry.meta.priority or "?"))
      if entry.meta.tags and #entry.meta.tags > 0 then
        table.insert(lines, "Tags: " .. table.concat(entry.meta.tags, ", "))
      end
      table.insert(lines, "")
      table.insert(lines, entry.body or "(empty)")
    end

    return ok(table.concat(lines, "\n"))
  end,
})

-- ── Tool: KBList ─────────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBList",
  description = "List all entries in the project knowledge base, optionally filtered by category, status, or tag. Shows a summary table of all matching entries.",
  schema      = KB_LIST_SCHEMA,
  execute     = function(input_json)
    local input = input_json

    ensure_init()

    local filter = {}
    if input.category then filter.category = input.category end
    if input.status then filter.status = input.status end
    if input.tag then filter.tag = input.tag end

    local entries = storage.list_entries(filter)
    if #entries == 0 then
      local msg = "No entries found"
      if input.category then msg = msg .. " in category: " .. input.category end
      if input.status then msg = msg .. " with status: " .. input.status end
      if input.tag then msg = msg .. " with tag: " .. input.tag end
      return ok(msg)
    end

    local lines = {
      "Knowledge Base: " .. #entries .. " entries",
      "",
      string.format("%-8s | %-12s | %-12s | %s", "ID", "Category", "Status", "Title"),
      string.format("%-8s-+-%-12s-+-%-12s-+-%s", "--------", "------------", "------------", "-------------------"),
    }

    for _, entry in ipairs(entries) do
      table.insert(lines, format_entry_summary(entry))
    end

    return ok(table.concat(lines, "\n"))
  end,
})

-- ── Tool: KBGet ──────────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBGet",
  description = "Get the full content of a knowledge base entry by its ID (e.g. F-001, D-002). Returns complete metadata and markdown body.",
  schema      = KB_GET_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    if not input.id or input.id == "" then
      return err("id is required")
    end

    ensure_init()

    local meta, body, path = storage.get_entry(input.id)
    if not meta then
      return err("entry not found: " .. input.id)
    end

    local lines = {
      "ID:       " .. (meta.id or "?"),
      "Title:    " .. (meta.title or "Untitled"),
      "Category: " .. (meta.category or "?"),
      "Status:   " .. (meta.status or "?"),
      "Priority: " .. (meta.priority or "?"),
      "Tags:     " .. (meta.tags and #meta.tags > 0 and table.concat(meta.tags, ", ") or "(none)"),
      "Created:  " .. (meta.created or "?"),
      "Updated:  " .. (meta.updated or "?"),
      "Path:     " .. (path or "?"),
      "",
      "--- Content ---",
      "",
      body or "(empty)",
    }

    return ok(table.concat(lines, "\n"))
  end,
})

-- ── Tool: KBUpdate ───────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBUpdate",
  description = "Update an existing knowledge base entry. Can update metadata (status, tags, priority, title) and/or replace or append to the content body. Use 'append' to add notes without overwriting.",
  schema      = KB_UPDATE_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    if not input.id or input.id == "" then
      return err("id is required")
    end

    ensure_init()

    local meta, body, old_path = storage.get_entry(input.id)
    if not meta then
      return err("entry not found: " .. input.id)
    end

    -- Update metadata fields
    if input.title then meta.title = input.title end
    if input.status then meta.status = input.status end
    if input.tags then meta.tags = input.tags end
    if input.priority then meta.priority = input.priority end

    -- Update body
    if input.content then
      if _config.use_ai then
        local _, structured = ai_mod.structure(input.content, meta.category, meta.title)
        if structured then
          body = structured
        else
          body = "# " .. meta.title .. "\n\n" .. input.content .. "\n"
        end
      else
        body = "# " .. meta.title .. "\n\n" .. input.content .. "\n"
      end
    elseif input.append then
      body = (body or "") .. "\n\n## Update — " .. os.date("%Y-%m-%d") .. "\n\n" .. input.append .. "\n"
    end

    -- Delete old file and save updated
    if old_path then
      os.remove(old_path)
    end
    local path = storage.save_entry(meta, body)

    -- Regenerate index
    index.write(storage)

    return ok(string.format(
      "Updated %s: %s — %s\nStatus: %s | Priority: %s\nSaved: %s",
      meta.category, meta.id, meta.title,
      meta.status, meta.priority,
      path
    ))
  end,
})

-- ── Tool: KBDelete ───────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBDelete",
  description = "Delete a knowledge base entry by ID. This is permanent.",
  schema      = KB_DELETE_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    if not input.id or input.id == "" then
      return err("id is required")
    end

    ensure_init()

    local success, e = storage.delete_entry(input.id)
    if not success then return err(e) end

    -- Regenerate index
    index.write(storage)

    return ok("Deleted entry: " .. input.id)
  end,
})

-- ── Tool: KBExport ───────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBExport",
  description = "Generate documentation from the knowledge base. 'index' creates a summary index.md. 'full' creates a consolidated single-file export of all entries.",
  schema      = KB_EXPORT_SCHEMA,
  execute     = function(input_json)
    local input = input_json
    local format = input.format or "index"

    ensure_init()

    if format == "full" then
      local path = index.write_export(storage)
      return ok("Full export generated: " .. path)
    else
      local path = index.write(storage)
      return ok("Index regenerated: " .. path)
    end
  end,
})

-- ── Tool: KBInit ─────────────────────────────────────────────────────────────

claudio.tools.register({
  name        = "KBInit",
  description = "Initialize the knowledge base directory structure for the current project. Safe to call multiple times. Creates category directories (feature, decision, architecture, sprint, note) and an index.md.",
  schema      = [[{"type":"object","properties":{}}]],
  execute     = function(_)
    local base = storage.init_kb()
    index.write(storage)
    return ok("Knowledge base initialized at: " .. base
      .. "\nCategories: feature, decision, architecture, sprint, note"
      .. "\nIndex: " .. base .. "/index.md")
  end,
})

-- ── Agent ─────────────────────────────────────────────────────────────────────

claudio.agents.register({
  name        = "documenter",
  description = "Project knowledge manager and technical writer. Maintains the project knowledge base — logs features, decisions, architecture docs, sprint summaries, and notes. Use for documenting project decisions, creating feature specs, capturing architecture designs, and building a living project knowledge base.",
  model       = "claude-sonnet-4-6",
  tools       = {
    "KBInit", "KBLog", "KBQuery", "KBList", "KBGet", "KBUpdate", "KBDelete", "KBExport",
    "Read", "Glob", "Grep",
  },
  system      = [[You are an expert technical writer and project knowledge manager. You maintain a structured knowledge base that serves as the single source of truth for the project.

# ROLE
- Capture and structure project knowledge: features, decisions, architecture, sprints, notes
- Write clear, concise technical documentation
- Keep entries well-organized with proper categorization, tags, and status
- Prevent duplicate entries — always search (KBQuery) before creating
- Maintain consistent formatting across all entries

# CATEGORIES
- feature: user-facing functionality, capabilities, behaviors
- decision: technical choices (ADR-style: context, decision, consequences, alternatives)
- architecture: system design, components, data flow, infrastructure
- sprint: sprint goals, retrospectives, iteration summaries
- note: general learnings, research, observations

# STATUS LIFECYCLE
planned → in-progress → done (or deprecated)

# BEST PRACTICES
1. Always KBQuery first to check for existing entries before creating new ones
2. Use descriptive titles (max 80 chars)
3. Tag entries with 2-5 relevant lowercase tags
4. For decisions, always document context, the decision itself, and consequences
5. For features, include acceptance criteria when possible
6. Link related entries by referencing their IDs in the body
7. Update status as work progresses — don't let entries go stale
8. Run KBExport periodically to keep the index current

# WRITING STYLE
- Professional, concise technical prose
- Use bullet points for lists
- Use headers to organize long entries
- Prefer concrete over abstract language
- Include code references (file paths, function names) when relevant]],
})

-- ── Skills ────────────────────────────────────────────────────────────────────

claudio.skills.register({
  name     = "kb",
  path     = plugin_dir .. "/skills/kb-guide.md",
  triggers = { "knowledge base", "kb", "document", "log feature", "log decision", "adr", "project docs" },
})

return M
