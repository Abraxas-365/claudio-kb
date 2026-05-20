-- lib/ai.lua
-- AI-powered classification and structuring of knowledge base entries.
-- Uses claudio.llm.complete with a small model to process freeform input.

local ai = {}

local DEFAULT_MODEL = "claude-haiku-4-5-20251001"

local _model = DEFAULT_MODEL

function ai.set_model(model)
  _model = model or DEFAULT_MODEL
end

-- ── Classification ───────────────────────────────────────────────────────────

local CLASSIFY_SYSTEM = [[You are a project knowledge base classifier. Given freeform input about a software project, you must:

1. Classify it into exactly ONE category: feature, decision, architecture, sprint, note
2. Extract a concise title (max 80 chars)
3. Determine a status: planned, in-progress, done, deprecated
4. Extract relevant tags (1-5 lowercase single-word tags)
5. Determine priority: low, medium, high, critical

Category guidelines:
- feature: new functionality, capabilities, user-facing changes
- decision: technical choices, trade-offs, ADRs (architecture decision records)
- architecture: system design, component structure, data flow, infrastructure
- sprint: sprint goals, retrospectives, iteration summaries
- note: general observations, learnings, research, anything else

Respond ONLY with valid JSON, no markdown fences:
{"category":"...","title":"...","status":"...","tags":["..."],"priority":"..."}]]

function ai.classify(input_text)
  local ok, result = pcall(function()
    return claudio.llm.complete({
      model    = _model,
      system   = CLASSIFY_SYSTEM,
      messages = {
        { role = "user", content = input_text },
      },
      max_tokens = 256,
    })
  end)

  if not ok or not result or not result.text then
    -- Fallback: basic heuristic classification
    return ai.classify_heuristic(input_text)
  end

  local text = result.text:gsub("```json", ""):gsub("```", ""):match("%b{}")
  if not text then
    return ai.classify_heuristic(input_text)
  end

  local parse_ok, data = pcall(parse_json, text)
  if not parse_ok or not data then
    return ai.classify_heuristic(input_text)
  end

  return {
    category = data.category or "note",
    title    = data.title or "Untitled",
    status   = data.status or "planned",
    tags     = data.tags or {},
    priority = data.priority or "medium",
  }
end

-- Heuristic fallback when AI is unavailable
function ai.classify_heuristic(input_text)
  local lower = input_text:lower()
  local category = "note"
  local status = "planned"

  -- Simple keyword matching
  if lower:find("decided") or lower:find("decision") or lower:find("chose")
    or lower:find("trade%-off") or lower:find("adr") or lower:find("alternative") then
    category = "decision"
  elseif lower:find("feature") or lower:find("implement") or lower:find("add support")
    or lower:find("user can") or lower:find("as a user") then
    category = "feature"
  elseif lower:find("architecture") or lower:find("component") or lower:find("system design")
    or lower:find("data flow") or lower:find("infrastructure") then
    category = "architecture"
  elseif lower:find("sprint") or lower:find("retrospective") or lower:find("iteration")
    or lower:find("velocity") then
    category = "sprint"
  end

  if lower:find("in progress") or lower:find("working on") or lower:find("started") then
    status = "in-progress"
  elseif lower:find("completed") or lower:find("done") or lower:find("finished") then
    status = "done"
  elseif lower:find("deprecated") or lower:find("removed") or lower:find("abandoned") then
    status = "deprecated"
  end

  -- Extract a title from the first line or sentence
  local title = input_text:match("^([^\n]+)") or "Untitled"
  if #title > 80 then title = title:sub(1, 77) .. "..." end

  return {
    category = category,
    title    = title,
    status   = status,
    tags     = {},
    priority = "medium",
  }
end

-- ── Structuring ──────────────────────────────────────────────────────────────

local STRUCTURE_SYSTEM = [[You are a technical documentation writer. Given freeform input and a category, produce well-structured markdown content (NO frontmatter, just the body).

Follow the template for the given category:

FEATURE:
# {title}

## Description
{clear description of the feature}

## Acceptance Criteria
{bullet points of acceptance criteria}

## Technical Notes
{implementation notes if any}

DECISION:
# {title}

## Context
{what motivated this decision}

## Decision
{what was decided}

## Consequences
{positive and negative consequences}

## Alternatives Considered
{other options that were evaluated}

ARCHITECTURE:
# {title}

## Overview
{high-level description}

## Components
{key components and their roles}

## Data Flow
{how data moves through the system}

## Dependencies
{external dependencies and constraints}

SPRINT:
# {title}

## Goal
{sprint goal}

## Completed
{what was done}

## Retrospective
### What went well
### What could improve
### Action items

NOTE:
# {title}

{well-organized content with appropriate headers}

Write clear, concise technical prose. Use bullet points for lists. Keep it professional.
Respond with ONLY the markdown body, no frontmatter.]]

function ai.structure(input_text, category, title)
  local ok, result = pcall(function()
    return claudio.llm.complete({
      model    = _model,
      system   = STRUCTURE_SYSTEM,
      messages = {
        { role = "user", content = string.format(
          "Category: %s\nTitle: %s\n\nInput:\n%s",
          category, title, input_text
        )},
      },
      max_tokens = 2048,
    })
  end)

  if not ok or not result or not result.text then
    return nil
  end

  return result.text
end

-- ── Combined: classify + structure ───────────────────────────────────────────

function ai.process(input_text, opts)
  opts = opts or {}

  -- Step 1: Classify (or use provided overrides)
  local classification
  if opts.category and opts.title then
    classification = {
      category = opts.category,
      title    = opts.title,
      status   = opts.status or "planned",
      tags     = opts.tags or {},
      priority = opts.priority or "medium",
    }
  else
    classification = ai.classify(input_text)
    -- Allow partial overrides
    if opts.category then classification.category = opts.category end
    if opts.title then classification.title = opts.title end
    if opts.status then classification.status = opts.status end
    if opts.tags then classification.tags = opts.tags end
    if opts.priority then classification.priority = opts.priority end
  end

  -- Step 2: Structure the content
  local body = ai.structure(input_text, classification.category, classification.title)
  if not body then
    -- Fallback: use the raw input with a title header
    body = "# " .. classification.title .. "\n\n" .. input_text .. "\n"
  end

  return classification, body
end

return ai
