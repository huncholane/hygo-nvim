local M = {}

local panel = {
  buf = nil,
  win = nil,
  sid = nil,
  width = 80,
}

local function ensure_buf()
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
    return panel.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buflisted = false
  pcall(vim.api.nvim_buf_set_name, buf, "claude://panel")
  panel.buf = buf

  local function open_input() M.open_input() end
  vim.keymap.set("n", "i", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "a", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "o", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "<CR>", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "q", function() M.close() end, { buffer = buf, desc = "Claude: close panel" })
  vim.bo[buf].modifiable = false
  return buf
end

local function scroll_to_bottom()
  if panel.win and vim.api.nvim_win_is_valid(panel.win) then
    local lc = vim.api.nvim_buf_line_count(panel.buf)
    pcall(vim.api.nvim_win_set_cursor, panel.win, { lc, 0 })
  end
end

local function append_lines(lines)
  local buf = panel.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.bo[buf].modifiable = false
  scroll_to_bottom()
end

local function append_text_streaming(text)
  local buf = panel.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  local lc = vim.api.nvim_buf_line_count(buf)
  local last = vim.api.nvim_buf_get_lines(buf, lc - 1, lc, false)[1] or ""
  local parts = vim.split(text, "\n", { plain = true })
  parts[1] = last .. parts[1]
  vim.api.nvim_buf_set_lines(buf, lc - 1, lc, false, parts)
  vim.bo[buf].modifiable = false
  scroll_to_bottom()
end

local function clear_buf()
  local buf = panel.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
end

function M.setup(opts)
  panel.width = opts.width or 80
end

function M.open_panel()
  local buf = ensure_buf()
  if panel.win and vim.api.nvim_win_is_valid(panel.win) then
    vim.api.nvim_set_current_win(panel.win)
    return
  end
  vim.cmd("botright vsplit")
  panel.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(panel.win, buf)
  vim.api.nvim_win_set_width(panel.win, panel.width)
  vim.wo[panel.win].wrap = true
  vim.wo[panel.win].linebreak = true
  vim.wo[panel.win].number = false
  vim.wo[panel.win].relativenumber = false
  scroll_to_bottom()
end

function M.close()
  if panel.win and vim.api.nvim_win_is_valid(panel.win) then
    vim.api.nvim_win_hide(panel.win)
    panel.win = nil
  end
end

function M.is_open()
  return panel.win and vim.api.nvim_win_is_valid(panel.win)
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    if not panel.sid then
      M.start_new()
    else
      M.open_panel()
    end
  end
end

function M.start_new()
  local runner = require("claude.runner")
  local sid = runner.start_session()
  panel.sid = sid
  clear_buf()
  M.open_panel()
  append_lines({
    "# Claude — new session",
    "_id: " .. sid:sub(1, 8) .. "_",
    "",
    "Press `i` to send a prompt. `q` closes the panel.",
    "",
  })
end

local function claude_jsonl_path(claude_id)
  if not claude_id then return nil end
  local cwd = vim.fn.getcwd()
  local enc = cwd:gsub("[/%.]", "-")
  local home = vim.uv.os_homedir() or os.getenv("HOME") or ""
  return home .. "/.claude/projects/" .. enc .. "/" .. claude_id .. ".jsonl"
end

local function replay_history(claude_id)
  local path = claude_jsonl_path(claude_id)
  if not path then return false end
  local f = io.open(path, "r")
  if not f then return false end
  local turns = 0
  for line in f:lines() do
    local ok, evt = pcall(vim.json.decode, line)
    if ok and type(evt) == "table" and evt.message then
      local msg = evt.message
      if msg.role == "user" then
        local text
        if type(msg.content) == "string" then
          text = msg.content
        elseif type(msg.content) == "table" then
          local parts = {}
          for _, b in ipairs(msg.content) do
            if type(b) == "table" and b.type == "text" and b.text then
              table.insert(parts, b.text)
            end
          end
          text = table.concat(parts, "\n")
        end
        if text and text ~= "" and not text:match("^<") then
          append_lines({ "## You", "" })
          for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
            append_lines({ l })
          end
          append_lines({ "" })
          turns = turns + 1
        end
      elseif msg.role == "assistant" and type(msg.content) == "table" then
        local parts = {}
        local tools = {}
        for _, b in ipairs(msg.content) do
          if type(b) == "table" then
            if b.type == "text" and b.text then
              table.insert(parts, b.text)
            elseif b.type == "tool_use" then
              local p = (b.input and b.input.file_path) or ""
              table.insert(tools, "> **" .. (b.name or "tool") .. "** `" .. p .. "`")
            end
          end
        end
        if #parts > 0 or #tools > 0 then
          append_lines({ "## Claude", "" })
          for _, t in ipairs(parts) do
            for _, l in ipairs(vim.split(t, "\n", { plain = true })) do
              append_lines({ l })
            end
          end
          for _, t in ipairs(tools) do
            append_lines({ "", t })
          end
          append_lines({ "", "---", "" })
        end
      end
    end
  end
  f:close()
  return turns > 0
end

function M.resume_last()
  local runner = require("claude.runner")
  local sid = runner.resume_from_pointer()
  if not sid then
    vim.notify("claude: no previous session to resume", vim.log.levels.WARN)
    M.start_new()
    return
  end
  panel.sid = sid
  clear_buf()
  M.open_panel()
  local session = runner.get_session(sid)
  append_lines({
    "# Claude — resumed",
    "_id: " .. sid:sub(1, 8) .. (session.claude_id and ("  ←  " .. session.claude_id:sub(1, 8)) or "") .. "_",
    "",
  })
  local replayed = replay_history(session.claude_id)
  if not replayed then
    append_lines({ "_(no prior transcript found on disk)_", "" })
  end
  append_lines({ "Press `i` to send a prompt.", "" })
end

function M.open_input()
  if not panel.sid then
    M.start_new()
  end
  local sid = panel.sid
  local input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[input_buf].bufhidden = "wipe"
  vim.bo[input_buf].filetype = "markdown"

  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.6)))
  local height = 8
  local win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Claude prompt — <C-s> send  <C-c> cancel ",
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
  local function send()
    if closed then return end
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    close()
    if text:match("^%s*$") then return end
    local runner = require("claude.runner")
    local ok, err = runner.send(sid, text)
    if not ok then
      vim.notify("claude: " .. tostring(err), vim.log.levels.WARN)
    end
  end
  local km = { buffer = input_buf, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", send, km)
  vim.keymap.set({ "n", "i" }, "<C-c>", close, km)
  vim.keymap.set("n", "q", close, km)
  vim.keymap.set("n", "<Esc>", close, km)
end

-- runner callbacks

function M.append_user_prompt(sid, text)
  if sid ~= panel.sid then return end
  vim.schedule(function()
    local lines = { "## You", "" }
    for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
      table.insert(lines, l)
    end
    table.insert(lines, "")
    table.insert(lines, "## Claude")
    table.insert(lines, "")
    append_lines(lines)
  end)
end

function M.append_assistant_text(sid, text)
  if sid ~= panel.sid then return end
  vim.schedule(function() append_text_streaming(text) end)
end

function M.append_tool_use(sid, name, path)
  if sid ~= panel.sid then return end
  vim.schedule(function()
    append_lines({ "", "> **" .. name .. "** `" .. path .. "`", "" })
  end)
end

function M.append_separator(sid)
  if sid ~= panel.sid then return end
  vim.schedule(function() append_lines({ "", "---", "" }) end)
end

function M.append_stderr(sid, line)
  if sid ~= panel.sid then return end
  vim.schedule(function() append_lines({ "_stderr: " .. line .. "_" }) end)
end

function M.on_prompt_complete(sid, prompt, had_changes)
  if sid ~= panel.sid then return end
  if had_changes then
    vim.schedule(function()
      append_lines({ "_recorded — " .. #(prompt.files or {}) .. " file(s) changed_", "" })
    end)
  end
end

function M.current_sid()
  return panel.sid
end

return M
