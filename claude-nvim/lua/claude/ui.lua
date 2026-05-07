local M = {}

local default_width = 80

-- panels keyed by tabpage handle
local panels = {}

-- forward declarations
local ensure_panel_for_current_tab

local SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function new_panel(tab)
  return {
    tab = tab,
    buf = nil,
    win = nil,
    sid = nil,
    width = default_width,
    autoscroll = true,
    spinner = {
      timer = nil,
      frame = 1,
      active = false,
      row = nil,
    },
  }
end

local function get_panel()
  local tab = vim.api.nvim_get_current_tabpage()
  local p = panels[tab]
  if not p then
    p = new_panel(tab)
    panels[tab] = p
  end
  return p
end

local function find_panel_by_sid(sid)
  if not sid then return nil end
  for _, p in pairs(panels) do
    if p.sid == sid then return p end
  end
  return nil
end

local function spinner_text(p)
  return SPINNER_FRAMES[p.spinner.frame] .. " thinking…"
end

local function scroll_to_bottom_now(p)
  if not p.autoscroll then return end
  if p.win and vim.api.nvim_win_is_valid(p.win) then
    pcall(vim.api.nvim_win_call, p.win, function()
      vim.cmd("normal! G")
    end)
  end
end

local function update_autoscroll_from_view(p)
  if not p.win or not vim.api.nvim_win_is_valid(p.win) then return end
  if not p.buf or not vim.api.nvim_buf_is_valid(p.buf) then return end
  local info = vim.fn.getwininfo(p.win)[1]
  if not info then return end
  local lc = vim.api.nvim_buf_line_count(p.buf)
  -- treat "near bottom" (within 1 line) as still autoscrolling, so the
  -- spinner row toggling does not yank the flag off.
  p.autoscroll = (info.botline >= lc - 1)
end

local function spinner_remove_if_present(p)
  if p.spinner.row == nil then return end
  if not p.buf or not vim.api.nvim_buf_is_valid(p.buf) then
    p.spinner.row = nil
    return
  end
  local lc = vim.api.nvim_buf_line_count(p.buf)
  if p.spinner.row < lc then
    vim.bo[p.buf].modifiable = true
    pcall(vim.api.nvim_buf_set_lines, p.buf, p.spinner.row, p.spinner.row + 1, false, {})
    vim.bo[p.buf].modifiable = false
  end
  p.spinner.row = nil
end

local function spinner_render(p)
  if not p.spinner.active then return end
  if not p.buf or not vim.api.nvim_buf_is_valid(p.buf) then return end
  vim.bo[p.buf].modifiable = true
  if p.spinner.row ~= nil and p.spinner.row < vim.api.nvim_buf_line_count(p.buf) then
    pcall(vim.api.nvim_buf_set_lines, p.buf, p.spinner.row, p.spinner.row + 1, false, { spinner_text(p) })
  else
    local lc = vim.api.nvim_buf_line_count(p.buf)
    pcall(vim.api.nvim_buf_set_lines, p.buf, lc, lc, false, { spinner_text(p) })
    p.spinner.row = lc
  end
  vim.bo[p.buf].modifiable = false
  scroll_to_bottom_now(p)
end

local function spinner_stop(p)
  p.spinner.active = false
  if p.spinner.timer then
    p.spinner.timer:stop()
    if not p.spinner.timer:is_closing() then p.spinner.timer:close() end
    p.spinner.timer = nil
  end
  spinner_remove_if_present(p)
end

local function spinner_start(p)
  spinner_stop(p)
  p.spinner.active = true
  p.spinner.frame = 1
  spinner_render(p)
  p.spinner.timer = vim.uv.new_timer()
  p.spinner.timer:start(90, 90, vim.schedule_wrap(function()
    if not p.spinner.active then return end
    p.spinner.frame = (p.spinner.frame % #SPINNER_FRAMES) + 1
    spinner_render(p)
  end))
end

local function ensure_buf(p)
  if p.buf and vim.api.nvim_buf_is_valid(p.buf) then
    return p.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buflisted = false
  pcall(vim.api.nvim_buf_set_name, buf, "claude://panel/" .. tostring(p.tab))
  p.buf = buf

  local function open_input() M.open_input() end
  vim.keymap.set("n", "i", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "a", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "o", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "<CR>", open_input, { buffer = buf, desc = "Claude: prompt" })
  vim.keymap.set("n", "q", function() M.close() end, { buffer = buf, desc = "Claude: close panel" })
  vim.bo[buf].modifiable = false
  return buf
end

local function append_lines(p, lines)
  local buf = p.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  spinner_remove_if_present(p)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.bo[buf].modifiable = false
  spinner_render(p)
  scroll_to_bottom_now(p)
end

local function append_text_streaming(p, text)
  local buf = p.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  spinner_remove_if_present(p)
  vim.bo[buf].modifiable = true
  local lc = vim.api.nvim_buf_line_count(buf)
  local last = vim.api.nvim_buf_get_lines(buf, lc - 1, lc, false)[1] or ""
  local parts = vim.split(text, "\n", { plain = true })
  parts[1] = last .. parts[1]
  vim.api.nvim_buf_set_lines(buf, lc - 1, lc, false, parts)
  vim.bo[buf].modifiable = false
  spinner_render(p)
  scroll_to_bottom_now(p)
end

local function clear_buf(p)
  local buf = p.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  p.spinner.row = nil
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
end

function M.setup(opts)
  default_width = opts.width or 80

  vim.api.nvim_create_autocmd("TabClosed", {
    callback = function(ev)
      local tabnr = tonumber(ev.file)
      if not tabnr then return end
      for tab, _ in pairs(panels) do
        if not vim.api.nvim_tabpage_is_valid(tab) then
          panels[tab] = nil
        end
      end
    end,
  })
end

function M.open_panel()
  local p = get_panel()
  local buf = ensure_buf(p)
  if p.win and vim.api.nvim_win_is_valid(p.win) then
    vim.api.nvim_set_current_win(p.win)
    return
  end
  vim.cmd("botright vsplit")
  p.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(p.win, buf)
  vim.api.nvim_win_set_width(p.win, p.width)
  vim.wo[p.win].wrap = true
  vim.wo[p.win].linebreak = true
  vim.wo[p.win].number = false
  vim.wo[p.win].relativenumber = false
  p.autoscroll = true

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = vim.api.nvim_create_augroup("ClaudePanelScroll_" .. p.tab, { clear = true }),
    callback = function(args)
      local wid = tonumber(args.match)
      if wid ~= p.win then return end
      update_autoscroll_from_view(p)
    end,
  })

  scroll_to_bottom_now(p)
end

function M.close()
  local p = get_panel()
  if p.win and vim.api.nvim_win_is_valid(p.win) then
    vim.api.nvim_win_hide(p.win)
    p.win = nil
  end
end

function M.is_open()
  local p = get_panel()
  return p.win and vim.api.nvim_win_is_valid(p.win)
end

function M.toggle()
  if M.is_open() then
    M.close()
    return
  end
  ensure_panel_for_current_tab()
end

function M.start_new()
  local p = get_panel()
  local runner = require("claude.runner")
  local sid = runner.start_session()
  p.sid = sid
  clear_buf(p)
  M.open_panel()
  append_lines(p, {
    "# Claude — new session",
    "_id: " .. sid:sub(1, 8) .. "_",
    "",
    "Press `i` to send a prompt. `q` closes the panel.",
    "",
  })
end

local function claude_jsonl_path(claude_id, cwd)
  if not claude_id then return nil end
  cwd = cwd or vim.fn.getcwd()
  local enc = cwd:gsub("[/%.]", "-")
  local home = vim.uv.os_homedir() or os.getenv("HOME") or ""
  return home .. "/.claude/projects/" .. enc .. "/" .. claude_id .. ".jsonl"
end

local function replay_history(p, claude_id, cwd)
  local path = claude_jsonl_path(claude_id, cwd)
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
          append_lines(p, { "## You", "" })
          for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
            append_lines(p, { l })
          end
          append_lines(p, { "" })
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
              local fp = (b.input and b.input.file_path) or ""
              table.insert(tools, "> **" .. (b.name or "tool") .. "** `" .. fp .. "`")
            end
          end
        end
        if #parts > 0 or #tools > 0 then
          append_lines(p, { "## Claude", "" })
          for _, t in ipairs(parts) do
            for _, l in ipairs(vim.split(t, "\n", { plain = true })) do
              append_lines(p, { l })
            end
          end
          for _, t in ipairs(tools) do
            append_lines(p, { "", t })
          end
          append_lines(p, { "", "---", "" })
        end
      end
    end
  end
  f:close()
  return turns > 0
end

local function has_open_panel_for_cwd(p, cwd)
  if not cwd then return false end
  local runner = require("claude.runner")
  for tab, op in pairs(panels) do
    if tab ~= p.tab and op.sid then
      local osess = runner.get_session(op.sid)
      if osess and osess.cwd == cwd then return true end
    end
  end
  return false
end

function M.resume_session(claude_id)
  if not claude_id or claude_id == "" then
    vim.notify("claude: missing claude_id", vim.log.levels.WARN)
    return
  end
  local p = get_panel()
  local runner = require("claude.runner")
  local store = require("claude.store")
  local cwd = vim.fn.getcwd()
  if has_open_panel_for_cwd(p, cwd) then
    vim.notify("claude: dialog already open for this directory in another tab — starting new", vim.log.levels.INFO)
    M.start_new()
    return
  end
  local session
  for _, entry in ipairs(store.list_sessions(cwd)) do
    local s = store.load_path(entry.path)
    if s and s.claude_id == claude_id then session = s break end
  end
  if not session then
    session = {
      id = store.uuid(),
      started_at = os.time(),
      cwd = cwd,
      claude_id = claude_id,
      prompts = {},
    }
  end
  local sid = runner.attach_existing(session)
  p.sid = sid
  store.write_pointer({ session_id = session.id, claude_id = claude_id, ts = os.time(), cwd = session.cwd })
  clear_buf(p)
  M.open_panel()
  append_lines(p, {
    "# Claude — resumed",
    "_id: " .. sid:sub(1, 8) .. "  ←  " .. claude_id:sub(1, 8) .. "_",
    "",
  })
  local replayed = replay_history(p, claude_id, session.cwd)
  if not replayed then
    append_lines(p, { "_(no prior transcript found on disk)_", "" })
  end
  append_lines(p, { "Press `i` to send a prompt.", "" })
end

function M.resume_last()
  local p = get_panel()
  local runner = require("claude.runner")
  local cwd = vim.fn.getcwd()
  if has_open_panel_for_cwd(p, cwd) then
    vim.notify("claude: dialog already open for this directory in another tab — starting new", vim.log.levels.INFO)
    M.start_new()
    return
  end
  local sid = runner.resume_from_pointer(cwd)
  if not sid then
    vim.notify("claude: no previous session to resume", vim.log.levels.WARN)
    M.start_new()
    return
  end
  p.sid = sid
  clear_buf(p)
  M.open_panel()
  local session = runner.get_session(sid)
  append_lines(p, {
    "# Claude — resumed",
    "_id: " .. sid:sub(1, 8) .. (session.claude_id and ("  ←  " .. session.claude_id:sub(1, 8)) or "") .. "_",
    "",
  })
  local replayed = replay_history(p, session.claude_id, session.cwd)
  if not replayed then
    append_lines(p, { "_(no prior transcript found on disk)_", "" })
  end
  append_lines(p, { "Press `i` to send a prompt.", "" })
end

local prompt_buf = nil
local prompt_keymaps_set = false

local function ensure_prompt_buf()
  if prompt_buf and vim.api.nvim_buf_is_valid(prompt_buf) then
    return prompt_buf
  end
  prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[prompt_buf].bufhidden = "hide"
  vim.bo[prompt_buf].filetype = "markdown"
  prompt_keymaps_set = false
  return prompt_buf
end

function M.open_input(opts)
  opts = opts or {}
  local p = get_panel()
  if not p.sid then
    M.start_new()
  end
  local sid = p.sid
  local return_to = opts.return_to
  local context = opts.context
  local input_buf = ensure_prompt_buf()

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
    title = context and " Claude prompt (with context) — <C-s> send  <C-c> cancel "
      or " Claude prompt — <C-s> send  <C-c> cancel ",
    title_pos = "center",
  })
  local lc = vim.api.nvim_buf_line_count(input_buf)
  local last = vim.api.nvim_buf_get_lines(input_buf, lc - 1, lc, false)[1] or ""
  pcall(vim.api.nvim_win_set_cursor, win, { lc, #last })
  vim.cmd("startinsert!")

  local closed = false
  local function close_keep()
    if closed then return end
    closed = true
    pcall(vim.cmd, "stopinsert")
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
    if return_to and vim.api.nvim_win_is_valid(return_to) then
      pcall(vim.api.nvim_set_current_win, return_to)
    end
  end
  local function send()
    if closed then return end
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    if text:match("^%s*$") then close_keep(); return end
    if vim.api.nvim_buf_is_valid(input_buf) then
      vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
    end
    local final_text = text
    if context and context ~= "" then
      final_text = context .. "\n\n" .. text
    end
    M.append_user_prompt(sid, final_text)
    close_keep()
    local runner = require("claude.runner")
    local ok, err = runner.send(sid, final_text, { skip_ui_prompt = true })
    if not ok then
      vim.notify("claude: " .. tostring(err), vim.log.levels.WARN)
    end
  end
  local km = { buffer = input_buf, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", send, km)
  vim.keymap.set({ "n", "i" }, "<C-c>", close_keep, km)
  vim.keymap.set("n", "q", close_keep, km)
  vim.keymap.set("n", "<Esc>", close_keep, km)
  prompt_keymaps_set = true
end

local function capture_visual_selection(bufnr)
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local sr, sc = s[2] - 1, s[3] - 1
  local er, ec = e[2] - 1, e[3]
  if sr < 0 or er < 0 then return "" end
  local mode = vim.fn.visualmode()
  if mode == "V" then
    local lines = vim.api.nvim_buf_get_lines(bufnr, sr, er + 1, false)
    return table.concat(lines, "\n")
  end
  local last_line = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
  ec = math.min(ec, #last_line)
  sc = math.max(0, sc)
  local ok, lines = pcall(vim.api.nvim_buf_get_text, bufnr, sr, sc, er, ec, {})
  if ok and lines then return table.concat(lines, "\n") end
  return ""
end

ensure_panel_for_current_tab = function()
  local p = get_panel()
  if M.is_open() then return p end
  if p.sid then
    M.open_panel()
    return p
  end
  local cwd = vim.fn.getcwd()
  local store = require("claude.store")
  local ptr = store.read_pointer(cwd)
  if ptr and not has_open_panel_for_cwd(p, cwd) then
    M.resume_last()
  else
    M.start_new()
  end
  return p
end

function M.prompt_visual_chat()
  local origin_buf = vim.api.nvim_get_current_buf()
  local origin_win = vim.api.nvim_get_current_win()
  if vim.fn.mode():match("^[vV\22]") then
    vim.cmd("noautocmd normal! \27")
  end
  local sel = capture_visual_selection(origin_buf)
  if sel == "" then
    vim.notify("claude: empty selection", vim.log.levels.WARN)
    return
  end
  local ft = vim.bo[origin_buf].filetype or ""
  local context = string.format("```%s\n%s\n```", ft, sel)

  ensure_panel_for_current_tab()
  M.open_input({ return_to = origin_win, context = context })
end

function M.open_prompt_keep_focus()
  local origin = vim.api.nvim_get_current_win()
  ensure_panel_for_current_tab()
  M.open_input({ return_to = origin })
end

-- runner callbacks (resolve panel by sid)

function M.append_user_prompt(sid, text)
  local p = find_panel_by_sid(sid)
  if not p then return end
  -- new prompt: snap viewport back to bottom and re-enable autoscroll
  p.autoscroll = true
  local lines = { "## You", "" }
  for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
    table.insert(lines, l)
  end
  table.insert(lines, "")
  table.insert(lines, "## Claude")
  table.insert(lines, "")
  append_lines(p, lines)
  spinner_start(p)
  scroll_to_bottom_now(p)
  pcall(vim.cmd, "redraw!")
end

function M.append_assistant_text(sid, text)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    append_text_streaming(p, text)
    spinner_render(p)
  end)
end

local ns_diff = vim.api.nvim_create_namespace("claude_panel_diff")

function M.append_diff(sid, lines)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    local buf = p.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    spinner_remove_if_present(p)
    vim.bo[buf].modifiable = true
    local start_row = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, start_row, start_row, false, lines)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    vim.bo[buf].modifiable = false
    for i, l in ipairs(lines) do
      local row = start_row + i - 1
      local hl
      local c = l:sub(1, 1)
      if c == "+" then hl = "DiffAdd"
      elseif c == "-" then hl = "DiffDelete"
      elseif l:sub(1, 2) == "@@" then hl = "DiffChange" end
      if hl then
        pcall(vim.api.nvim_buf_set_extmark, buf, ns_diff, row, 0, { line_hl_group = hl })
      end
    end
    spinner_render(p)
    scroll_to_bottom_now(p)
  end)
end

function M.append_tool_use(sid, name, summary)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    local line
    if summary and summary ~= "" then
      line = "> **" .. name .. "** `" .. summary .. "`"
    else
      line = "> **" .. name .. "**"
    end
    append_lines(p, { "", line, "" })
    spinner_render(p)
  end)
end

function M.append_separator(sid)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    spinner_stop(p)
    append_lines(p, { "", "---", "" })
  end)
end

function M.append_cancelled(sid)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    spinner_stop(p)
    append_lines(p, { "", "_— cancelled —_", "", "---", "" })
  end)
end

function M.cancel_current()
  local p = get_panel()
  local runner = require("claude.runner")
  local sid = p.sid
  if not sid then
    vim.notify("claude: no active session", vim.log.levels.WARN)
    return
  end
  if not runner.cancel(sid) then
    vim.notify("claude: nothing to cancel", vim.log.levels.WARN)
  end
end

function M.append_stderr(sid, line)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    append_lines(p, { "_stderr: " .. line .. "_" })
  end)
end

function M.on_prompt_complete(sid, prompt, had_changes)
  vim.schedule(function()
    local p = find_panel_by_sid(sid)
    if not p then return end
    spinner_stop(p)
    if had_changes then
      append_lines(p, { "_recorded — " .. #(prompt.files or {}) .. " file(s) changed_", "" })
    end
  end)
end

function M.current_sid()
  return get_panel().sid
end

-- Test seams (do not use outside specs).
function M._test_get_panel(tab)
  return panels[tab or vim.api.nvim_get_current_tabpage()]
end

function M._test_set_autoscroll(p, v)
  p.autoscroll = v
end

return M
