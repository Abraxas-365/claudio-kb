-- lib/index.lua
-- Auto-generate index.md and consolidated documentation from KB entries.

local index = {}

-- ── Lua stdlib file helpers ──────────────────────────────────────────────────

local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then return nil, "cannot open " .. path end
  f:write(content)
  f:close()
  return true
end

-- ── Index generation ─────────────────────────────────────────────────────────

local CATEGORY_LABELS = {
  feature      = "Features",
  decision     = "Decisions",
  architecture = "Architecture",
  sprint       = "Sprints",
  note         = "Notes",
}

local CATEGORY_ORDER = { "feature", "decision", "architecture", "sprint", "note" }

local STATUS_ICONS = {
  planned       = "[ ]",
  ["in-progress"] = "[~]",
  done          = "[x]",
  deprecated    = "[-]",
}

-- Generate the main index.md
function index.generate(storage)
  local lines = {
    "# Project Knowledge Base",
    "",
    "_Auto-generated index. Do not edit manually._",
    "",
    "Last updated: " .. os.date("%Y-%m-%d %H:%M"),
    "",
  }

  -- Summary stats
  local all = storage.list_entries()
  local stats = { total = #all }
  for _, cat in ipairs(CATEGORY_ORDER) do stats[cat] = 0 end
  local status_counts = {}
  for _, entry in ipairs(all) do
    local cat = entry.meta.category or "note"
    stats[cat] = (stats[cat] or 0) + 1
    local st = entry.meta.status or "planned"
    status_counts[st] = (status_counts[st] or 0) + 1
  end

  table.insert(lines, "## Summary")
  table.insert(lines, "")
  table.insert(lines, "| Category | Count |")
  table.insert(lines, "|----------|-------|")
  for _, cat in ipairs(CATEGORY_ORDER) do
    table.insert(lines, string.format("| %s | %d |", CATEGORY_LABELS[cat], stats[cat] or 0))
  end
  table.insert(lines, string.format("| **Total** | **%d** |", stats.total))
  table.insert(lines, "")

  -- Status breakdown
  table.insert(lines, "| Status | Count |")
  table.insert(lines, "|--------|-------|")
  for _, st in ipairs({ "planned", "in-progress", "done", "deprecated" }) do
    if (status_counts[st] or 0) > 0 then
      table.insert(lines, string.format("| %s | %d |", st, status_counts[st]))
    end
  end
  table.insert(lines, "")

  -- Entries by category
  for _, cat in ipairs(CATEGORY_ORDER) do
    local entries = storage.list_entries({ category = cat })
    if #entries > 0 then
      table.insert(lines, "## " .. CATEGORY_LABELS[cat])
      table.insert(lines, "")
      for _, entry in ipairs(entries) do
        local icon = STATUS_ICONS[entry.meta.status] or "[ ]"
        local tags = ""
        if entry.meta.tags and #entry.meta.tags > 0 then
          tags = " `" .. table.concat(entry.meta.tags, "` `") .. "`"
        end
        local rel_path = entry.path:match("/kb/(.+)$") or entry.path
        table.insert(lines, string.format(
          "- %s **%s** — [%s](%s)%s",
          icon,
          entry.meta.id or "?",
          entry.meta.title or "Untitled",
          rel_path,
          tags
        ))
      end
      table.insert(lines, "")
    end
  end

  return table.concat(lines, "\n")
end

-- Write index.md to the KB root
function index.write(storage)
  local content = index.generate(storage)
  local path = storage.get_base_path() .. "/index.md"
  write_file(path, content)
  return path
end

-- ── Export: consolidated single-file doc ──────────────────────────────────────

function index.export(storage, opts)
  opts = opts or {}
  local lines = {
    "# Project Knowledge Base — Full Export",
    "",
    "_Generated: " .. os.date("%Y-%m-%d %H:%M") .. "_",
    "",
    "---",
    "",
  }

  for _, cat in ipairs(CATEGORY_ORDER) do
    local entries = storage.list_entries({ category = cat })
    if #entries > 0 then
      table.insert(lines, "# " .. CATEGORY_LABELS[cat])
      table.insert(lines, "")
      for _, entry in ipairs(entries) do
        -- Entry header
        table.insert(lines, string.format("## %s: %s",
          entry.meta.id or "?",
          entry.meta.title or "Untitled"
        ))
        table.insert(lines, "")
        -- Metadata
        table.insert(lines, string.format(
          "> Status: **%s** | Priority: %s | Created: %s | Updated: %s",
          entry.meta.status or "planned",
          entry.meta.priority or "medium",
          entry.meta.created or "?",
          entry.meta.updated or "?"
        ))
        if entry.meta.tags and #entry.meta.tags > 0 then
          table.insert(lines, "> Tags: " .. table.concat(entry.meta.tags, ", "))
        end
        table.insert(lines, "")
        -- Body
        table.insert(lines, entry.body or "")
        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")
      end
    end
  end

  return table.concat(lines, "\n")
end

-- Write the full export
function index.write_export(storage, filename)
  filename = filename or "export.md"
  local content = index.export(storage)
  local path = storage.get_base_path() .. "/" .. filename
  write_file(path, content)
  return path
end

return index
