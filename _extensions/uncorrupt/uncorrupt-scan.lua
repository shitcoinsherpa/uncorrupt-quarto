-- UnCorrupt : Quarto shortcode
--
-- Use in a .qmd document:
--     {{< uncorrupt-scan path="data/supp_table_1.xlsx" >}}
--     {{< uncorrupt-scan path="supplementary/" recursive=true >}}
--
-- The shortcode shells out to `uncorrupt detect` (or `audit` if path is
-- a folder) at render time, parses the JSON, and emits a styled
-- Markdown table directly into the rendered document.
--
-- Requires:
--   - `uncorrupt` CLI on PATH (`pip install uncorrupt` or
--     `conda install -c bioconda uncorrupt`)
--   - Quarto >= 1.4

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_command(cmd)
  local handle = io.popen(cmd)
  if not handle then return nil, "io.popen failed" end
  local out = handle:read("*a")
  local ok, _, code = handle:close()
  return out, code
end

local function file_or_dir(path)
  -- crude check: does path end in .xlsx / .xls?
  local lower = path:lower()
  if lower:match("%.xlsx?$") then return "file" end
  return "dir"
end

local function render_table(suspicions)
  if #suspicions == 0 then
    return pandoc.RawBlock("markdown",
      "::: {.callout-tip title='UnCorrupt scan'}\n" ..
      "No corruption flags found.\n" ..
      ":::\n")
  end

  -- Group by confidence band
  local high, mid = {}, {}
  for _, s in ipairs(suspicions) do
    if s.confidence >= 0.95 then table.insert(high, s)
    elseif s.confidence >= 0.30 then table.insert(mid, s) end
  end

  local parts = {}
  table.insert(parts,
    "::: {.callout-important title='UnCorrupt scan'}\n" ..
    string.format("**%d high-confidence** + **%d mid-confidence** corruption flag(s) found.\n\n",
                   #high, #mid))

  local function rows(group, title)
    if #group == 0 then return end
    table.insert(parts, string.format("**%s (n=%d)**\n\n", title, #group))
    table.insert(parts, "| Kind | Sheet ! Col | Row | Value | Suggestion | Conf |\n")
    table.insert(parts, "|---|---|---:|---|---|---:|\n")
    for _, s in ipairs(group) do
      local loc = (s.sheet or "") .. " ! " .. tostring(s.column or "")
      local val = tostring(s.value or ""):sub(1, 40)
      local sug = tostring(s.suggestion or "")
      table.insert(parts, string.format("| `%s` | %s | %d | `%s` | %s | %.2f |\n",
        s.kind, loc, s.row, val, sug, s.confidence))
    end
    table.insert(parts, "\n")
  end

  rows(high, "High confidence (≥ 0.95)")
  rows(mid,  "Mid confidence (0.30 - 0.95)")
  table.insert(parts, ":::\n")
  return pandoc.RawBlock("markdown", table.concat(parts))
end

function uncorrupt_scan(args, kwargs)
  -- Read shortcode args. Path can be positional or kwarg.
  local path = nil
  if args and #args >= 1 then
    path = pandoc.utils.stringify(args[1])
  end
  if kwargs and kwargs["path"] then
    path = pandoc.utils.stringify(kwargs["path"])
  end
  if not path then
    return pandoc.RawBlock("markdown",
      "::: {.callout-warning}\n`{{< uncorrupt-scan >}}` requires a `path` argument.\n:::\n")
  end

  local recursive = kwargs and kwargs["recursive"]
                    and pandoc.utils.stringify(kwargs["recursive"]) == "true"

  local cmd
  if file_or_dir(path) == "file" then
    cmd = "uncorrupt detect --json " .. shell_quote(path)
  else
    cmd = "uncorrupt audit --json " .. shell_quote(path)
    if recursive then cmd = cmd .. " --recursive" end
  end

  local out, code = read_command(cmd .. " 2>/dev/null")
  if not out or out == "" then
    return pandoc.RawBlock("markdown",
      "::: {.callout-warning title='UnCorrupt scan failed'}\n" ..
      "Command `" .. cmd .. "` produced no output. Ensure `uncorrupt` is " ..
      "on PATH (`pip install uncorrupt`).\n:::\n")
  end

  local ok, parsed = pcall(quarto.json.decode, out)
  if not ok or not parsed then
    return pandoc.RawBlock("markdown",
      "::: {.callout-warning title='UnCorrupt scan parse error'}\n" ..
      "Could not parse JSON output from `uncorrupt`.\n:::\n")
  end

  -- `detect` returns {suspicions: [...]}, `audit` returns {file: {...}, ...}
  local suspicions = {}
  if parsed.suspicions then
    suspicions = parsed.suspicions
  else
    -- audit: flatten per-file kinds info into a summary
    for file, info in pairs(parsed) do
      if type(info) == "table" and (info.n_high_confidence or info.n_mid_confidence) then
        table.insert(suspicions, {
          sheet = "", column = file, row = 0,
          value = string.format("%d high + %d mid",
            info.n_high_confidence or 0, info.n_mid_confidence or 0),
          kind = "audit-summary",
          suggestion = table.concat(info.kinds or {}, ", "),
          confidence = (info.n_high_confidence or 0) > 0 and 0.95 or 0.30,
        })
      end
    end
  end

  return render_table(suspicions)
end

-- Quarto v1.4+ shortcode registration
return {
  ["uncorrupt-scan"] = uncorrupt_scan,
}
