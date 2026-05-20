-- lib/templates.lua
-- Markdown templates for each knowledge base category.
-- Used when AI structuring is disabled or as fallback.

local templates = {}

-- ── Feature template ─────────────────────────────────────────────────────────

function templates.feature(meta)
  local lines = {
    "# " .. (meta.title or "Untitled Feature"),
    "",
    "## Description",
    "",
    meta.description or "_Describe the feature here._",
    "",
    "## Acceptance Criteria",
    "",
    meta.acceptance_criteria or "_Define when this feature is complete._",
    "",
    "## Technical Notes",
    "",
    meta.technical_notes or "",
    "",
  }
  return table.concat(lines, "\n")
end

-- ── Decision template (ADR-style) ───────────────────────────────────────────

function templates.decision(meta)
  local lines = {
    "# " .. (meta.title or "Untitled Decision"),
    "",
    "## Context",
    "",
    meta.context or "_What is the issue that we're seeing that is motivating this decision?_",
    "",
    "## Decision",
    "",
    meta.decision or "_What is the change that we're proposing and/or doing?_",
    "",
    "## Consequences",
    "",
    meta.consequences or "_What becomes easier or more difficult to do because of this change?_",
    "",
    "## Alternatives Considered",
    "",
    meta.alternatives or "",
    "",
  }
  return table.concat(lines, "\n")
end

-- ── Architecture template ────────────────────────────────────────────────────

function templates.architecture(meta)
  local lines = {
    "# " .. (meta.title or "Untitled Architecture Doc"),
    "",
    "## Overview",
    "",
    meta.overview or "_High-level description of this component/system._",
    "",
    "## Components",
    "",
    meta.components or "",
    "",
    "## Data Flow",
    "",
    meta.data_flow or "",
    "",
    "## Dependencies",
    "",
    meta.dependencies or "",
    "",
    "## Constraints",
    "",
    meta.constraints or "",
    "",
  }
  return table.concat(lines, "\n")
end

-- ── Sprint template ──────────────────────────────────────────────────────────

function templates.sprint(meta)
  local lines = {
    "# " .. (meta.title or "Sprint"),
    "",
    "## Goal",
    "",
    meta.goal or "_What is the sprint goal?_",
    "",
    "## Completed",
    "",
    meta.completed or "",
    "",
    "## Carried Over",
    "",
    meta.carried_over or "",
    "",
    "## Retrospective",
    "",
    "### What went well",
    "",
    meta.retro_good or "",
    "",
    "### What could improve",
    "",
    meta.retro_improve or "",
    "",
    "### Action items",
    "",
    meta.retro_actions or "",
    "",
  }
  return table.concat(lines, "\n")
end

-- ── Note template ────────────────────────────────────────────────────────────

function templates.note(meta)
  local lines = {
    "# " .. (meta.title or "Untitled Note"),
    "",
    meta.content or meta.description or "",
    "",
  }
  return table.concat(lines, "\n")
end

-- ── Dispatcher ───────────────────────────────────────────────────────────────

function templates.render(category, meta)
  local fn = templates[category]
  if fn then return fn(meta) end
  return templates.note(meta)
end

return templates
