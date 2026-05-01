local M = {}

local skip_permissions = false

function M.setup(opts)
  if opts and opts.skip_permissions then skip_permissions = true end
end

local function strip_fences(text)
  local lines = vim.split(text or "", "\n", { plain = true })
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if #lines >= 2 and lines[1]:match("^```") then
    table.remove(lines, 1)
    if lines[#lines] and lines[#lines]:match("^```%s*$") then
      table.remove(lines)
    end
  end
  return table.concat(lines, "\n")
end

local function extract_json_array(text)
  local s = text:find("%[")
  local e = text:reverse():find("%]")
  if not s or not e then return text end
  return text:sub(s, #text - e + 1)
end

local function open_popup(on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.6)))
  local height = 6
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Claude find — <C-s> search  <C-c> cancel ",
    title_pos = "center",
  })
  vim.cmd("startinsert")
  local closed = false
  local function close()
    if closed then return end
    closed = true
    pcall(vim.cmd, "stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  local function submit()
    if closed then return end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local q = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    close()
    if q == "" then return end
    on_submit(q)
  end
  local km = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, km)
  vim.keymap.set({ "n", "i" }, "<C-c>", close, km)
  vim.keymap.set("n", "q", close, km)
  vim.keymap.set("n", "<Esc>", close, km)
end

function M.find()
  open_popup(function(query)
    vim.notify("claude: searching for '" .. query .. "'…")
    local prompt = "You are searching this codebase for snippets relevant to the user's query. "
      .. "Use the Grep, Glob, and Read tools as needed to find them. Return up to 20 results. "
      .. "Output ONLY a JSON array (no markdown fences, no commentary, no prose) of objects with keys: "
      .. 'path (absolute file path string), lnum (1-indexed integer line number), snippet (the matching line content, trimmed of leading/trailing whitespace).\n\n'
      .. "Query: " .. query
    local cmd = { "claude", "-p", prompt }
    if skip_permissions then table.insert(cmd, "--dangerously-skip-permissions") end
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        vim.notify("claude failed: " .. (out.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local raw = strip_fences(out.stdout or "")
      local json_text = extract_json_array(raw)
      local ok, results = pcall(vim.json.decode, json_text)
      if not ok or type(results) ~= "table" then
        vim.notify("claude: could not parse JSON response", vim.log.levels.ERROR)
        return
      end
      local items = { { text = "▌ " .. query, valid = 0 } }
      for _, r in ipairs(results) do
        if type(r) == "table" and r.path and r.lnum then
          table.insert(items, {
            filename = tostring(r.path),
            lnum = tonumber(r.lnum) or 1,
            text = ((r.snippet or "")):gsub("^%s+", ""):gsub("%s+$", ""),
          })
        end
      end
      if #items <= 1 then
        vim.notify("claude: no results for '" .. query .. "'", vim.log.levels.WARN)
        return
      end
      vim.fn.setqflist({}, " ", { title = query, items = items })
      vim.cmd("copen")
      pcall(vim.cmd, "cc 2")
      pcall(function() require("claude.highlights").refresh_all() end)
    end))
  end)
end

return M
