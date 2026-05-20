-- lib/storage.lua
-- File-based markdown storage for the knowledge base.
-- Each entry is a .md file with YAML-like frontmatter.
-- Organized in category directories under a configurable base path.

local storage = {}

-- ── Frontmatter parsing ──────────────────────────────────────────────────────

-- Parse YAML-like frontmatter from markdown content.
-- Returns (metadata_table, body_string).
function storage.parse_frontmatter(content)
  if not content then return {}, "" end

  local meta = {}
  local body = content

  -- Check for --- delimited frontmatter
  local fm_start, fm_end = content:find("^%-%-%-\n")
  if not fm_start then return meta, content end

  local close_start, close_end = content:find("\n%-%-%-\n", fm_end)
  if not close_start then return meta, content end

  local fm_text = content:sub(fm_end + 1, close_start - 1)
  body = content:sub(close_end + 1)

  for line in fm_text:gmatch("[^\n]+") do
    local key, value = line:match("^([%w_]+):%s*(.+)$")
    if key and value then
      -- Strip quotes if present
      value = value:gsub("^[\"'](.+)[\"']$", "%1")
      -- Parse arrays (comma-separated)
      if key == "tags" then
        local tags = {}
        for tag in value:gmatch("[^,]+") do
          tag = tag:match("^%s*(.-)%s*$")
          if tag ~= "" then table.insert(tags, tag) end
        end
        meta[key] = tags
      else
        meta[key] = value
      end
    end
  end

  return meta, body
end

-- Serialize metadata + body back to markdown with frontmatter.
function storage.render_frontmatter(meta, body)
  local lines = { "---" }

  -- Ordered keys for consistent output
  local key_order = {
    "id", "title", "category", "status", "tags",
    "priority", "created", "updated",
  }

  local seen = {}
  for _, key in ipairs(key_order) do
    if meta[key] then
      seen[key] = true
      if type(meta[key]) == "table" then
        table.insert(lines, key .. ": " .. table.concat(meta[key], ", "))
      else
        table.insert(lines, key .. ": " .. tostring(meta[key]))
      end
    end
  end

  -- Any remaining keys not in key_order
  for key, val in pairs(meta) do
    if not seen[key] then
      if type(val) == "table" then
        table.insert(lines, key .. ": " .. table.concat(val, ", "))
      else
        table.insert(lines, key .. ": " .. tostring(val))
      end
    end
  end

  table.insert(lines, "---")
  table.insert(lines, "")

  return table.concat(lines, "\n") .. (body or "")
end

-- ── Directory & path helpers ─────────────────────────────────────────────────

local _base_path = nil

function storage.set_base_path(path)
  _base_path = path
end

function storage.get_base_path()
  if _base_path then return _base_path end
  local h = io.popen("pwd")
  local cwd = h:read("*l")
  h:close()
  cwd = cwd:gsub("%s+$", "")
  return cwd .. "/kb"
end

function storage.category_path(category)
  return storage.get_base_path() .. "/" .. category
end

function storage.entry_path(category, filename)
  return storage.category_path(category) .. "/" .. filename
end

-- ── State file ───────────────────────────────────────────────────────────────
-- Stores auto-increment counters per category in kb/.state.json

local function state_path()
  return storage.get_base_path() .. "/.state.json"
end

function storage.load_state()
  local path = state_path()
  local out = claudio.fs.read(path)
  if not out or out == "" then
    return { counters = {} }
  end
  local ok, data = pcall(claudio.json.decode, out)
  if not ok then return { counters = {} } end
  return data
end

function storage.save_state(state)
  local path = state_path()
  local dir = storage.get_base_path()
  claudio.fs.mkdir(dir)
  claudio.fs.write(path, claudio.json.encode(state))
end

-- ── ID generation ────────────────────────────────────────────────────────────

local CATEGORY_PREFIX = {
  feature      = "F",
  decision     = "D",
  architecture = "A",
  sprint       = "S",
  note         = "N",
}

function storage.next_id(category)
  local state = storage.load_state()
  local prefix = CATEGORY_PREFIX[category] or category:sub(1, 1):upper()
  local counter = (state.counters[category] or 0) + 1
  state.counters[category] = counter
  storage.save_state(state)
  return string.format("%s-%03d", prefix, counter)
end

function storage.category_prefix(category)
  return CATEGORY_PREFIX[category] or category:sub(1, 1):upper()
end

function storage.categories()
  return { "feature", "decision", "architecture", "sprint", "note" }
end

-- ── File operations ──────────────────────────────────────────────────────────

-- Slugify a title for filenames
function storage.slugify(title)
  local slug = title:lower()
  slug = slug:gsub("[^%w%s-]", "")
  slug = slug:gsub("%s+", "-")
  slug = slug:gsub("%-+", "-")
  slug = slug:gsub("^%-+", ""):gsub("%-+$", "")
  if #slug > 60 then slug = slug:sub(1, 60):gsub("%-+$", "") end
  return slug
end

-- Save an entry (creates directory if needed)
function storage.save_entry(meta, body)
  local category = meta.category or "note"
  local dir = storage.category_path(category)
  claudio.fs.mkdir(dir)

  local slug = storage.slugify(meta.title or "untitled")
  local filename = meta.id:lower() .. "-" .. slug .. ".md"
  local path = storage.entry_path(category, filename)

  -- Update timestamp
  meta.updated = os.date("%Y-%m-%d")
  if not meta.created then
    meta.created = os.date("%Y-%m-%d")
  end

  local content = storage.render_frontmatter(meta, body)
  claudio.fs.write(path, content)

  return path, filename
end

-- Read an entry by ID (scans all categories)
-- claudio.fs.glob returns full paths; extract the basename for ID matching.
function storage.get_entry(id)
  id = id:upper()
  for _, cat in ipairs(storage.categories()) do
    local dir = storage.category_path(cat)
    local paths = claudio.fs.glob(dir .. "/*.md")
    if paths and #paths > 0 then
      for _, full_path in ipairs(paths) do
        -- Extract just the filename from the full path
        local file = full_path:match("([^/]+)$") or full_path
        if file:upper():find("^" .. id:gsub("%-", "%%-"), 1) then
          local content = claudio.fs.read(full_path)
          if content and content ~= "" then
            local meta, body = storage.parse_frontmatter(content)
            return meta, body, full_path
          end
        end
      end
    end
  end
  return nil, nil, nil
end

-- List all entries, optionally filtered
-- claudio.fs.glob returns full paths; no need to reconstruct path from dir + filename.
function storage.list_entries(filter)
  filter = filter or {}
  local entries = {}

  local cats = filter.category
    and { filter.category }
    or storage.categories()

  for _, cat in ipairs(cats) do
    local dir = storage.category_path(cat)
    local paths = claudio.fs.glob(dir .. "/*.md")
    if paths and #paths > 0 then
      for _, full_path in ipairs(paths) do
        local content = claudio.fs.read(full_path)
        if content and content ~= "" then
          local meta, body = storage.parse_frontmatter(content)
          meta.category = meta.category or cat

          -- Apply filters
          local match = true
          if filter.status and meta.status ~= filter.status then
            match = false
          end
          if filter.tag then
            local found = false
            for _, t in ipairs(meta.tags or {}) do
              if t:lower() == filter.tag:lower() then found = true; break end
            end
            if not found then match = false end
          end

          if match then
            table.insert(entries, { meta = meta, body = body, path = full_path })
          end
        end
      end
    end
  end

  -- Sort by ID
  table.sort(entries, function(a, b)
    return (a.meta.id or "") < (b.meta.id or "")
  end)

  return entries
end

-- Search entries by keyword in title, body, and tags
function storage.search_entries(query)
  if not query or query == "" then return storage.list_entries() end

  local all = storage.list_entries()
  local results = {}
  local q = query:lower()

  for _, entry in ipairs(all) do
    local score = 0
    local title = (entry.meta.title or ""):lower()
    local body = (entry.body or ""):lower()
    local tags = entry.meta.tags or {}

    -- Title match (highest weight)
    if title:find(q, 1, true) then score = score + 10 end

    -- Tag match
    for _, t in ipairs(tags) do
      if t:lower():find(q, 1, true) then score = score + 5 end
    end

    -- Body match
    if body:find(q, 1, true) then score = score + 1 end

    if score > 0 then
      entry.score = score
      table.insert(results, entry)
    end
  end

  -- Sort by relevance
  table.sort(results, function(a, b) return a.score > b.score end)

  return results
end

-- Delete an entry by ID
function storage.delete_entry(id)
  local meta, _, path = storage.get_entry(id)
  if not meta then return false, "entry not found: " .. id end
  os.remove(path)
  return true, nil
end

-- Check if KB is initialized
function storage.is_initialized()
  local base = storage.get_base_path()
  return claudio.fs.exists(base)
end

-- Initialize KB directory structure
function storage.init_kb()
  local base = storage.get_base_path()
  for _, cat in ipairs(storage.categories()) do
    claudio.fs.mkdir(base .. "/" .. cat)
  end
  -- Create .gitkeep files
  for _, cat in ipairs(storage.categories()) do
    local gk = base .. "/" .. cat .. "/.gitkeep"
    if not claudio.fs.exists(gk) then
      claudio.fs.write(gk, "")
    end
  end
  -- Initialize state if needed
  storage.load_state()
  return base
end

return storage
