local M = {}

local store = require("claude.store")

local skip_permissions = false
local debug_log = false
local active = {}

local function log(tag, line)
  if not debug_log then return end
  local path = vim.fn.stdpath("data") .. "/claude-nvim/debug.log"
  local f = io.open(path, "a")
  if not f then return end
  f:write(os.date("%H:%M:%S ") .. tag .. " " .. tostring(line) .. "\n")
  f:close()
end

function M.setup(opts)
  skip_permissions = opts.skip_permissions == true
  debug_log = opts.debug == true
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return "" end
  local c = f:read("*a") or ""
  f:close()
  return c
end

local function abs_path(path)
  if not path or path == "" then return nil end
  if path:sub(1, 1) ~= "/" then
    path = vim.fn.getcwd() .. "/" .. path
  end
  return vim.fn.fnamemodify(path, ":p")
end

local function compute_change(before, after)
  if before == after then return nil end
  local indices = vim.diff(before, after, { result_type = "indices", algorithm = "histogram" })
  local unified = vim.diff(before, after, { algorithm = "histogram" })
  local hunks = {}
  if type(indices) == "table" then
    for _, h in ipairs(indices) do
      local count_a = h[2]
      local start_b = h[3]
      local count_b = h[4]
      local s, e
      if count_b == 0 then
        s = math.max(1, start_b)
        e = s
      else
        s = start_b
        e = start_b + count_b - 1
      end
      table.insert(hunks, { start = s, finish = e, added = count_b, removed = count_a })
    end
  end
  if #hunks == 0 then return nil end
  return hunks, unified or ""
end

local function persist_pointer(st)
  store.write_pointer({
    session_id = st.session.id,
    claude_id = st.session.claude_id,
    ts = os.time(),
    cwd = st.session.cwd,
  })
end

local function flush_prompt(sid)
  local st = active[sid]
  if not st or not st.current_prompt then return end
  local p = st.current_prompt
  local files = {}
  for path, before in pairs(st.before_files) do
    local after = read_file(path)
    local hunks, unified = compute_change(before, after)
    if hunks then
      table.insert(files, {
        path = path,
        hunks = hunks,
        diff = unified,
        before_content = before,
        after_content = after,
      })
    end
  end
  st.current_prompt = nil
  st.before_files = {}

  if #files > 0 then
    p.files = files
    table.insert(st.session.prompts, p)
    store.save(st.session)
    vim.schedule(function()
      local ok_h, hl = pcall(require, "extensions.qf-line-highlights")
      if ok_h then hl.refresh_all() end
      local ok_t, tt = pcall(require, "claude.timetravel")
      if ok_t then tt.bump() end
    end)
  end

  vim.schedule(function()
    local ok_u, ui = pcall(require, "claude.ui")
    if ok_u then ui.on_prompt_complete(sid, p, #files > 0) end
  end)
end

local function ensure_before(sid, path)
  local st = active[sid]
  if not st or not path then return end
  if st.before_files[path] == nil then
    st.before_files[path] = read_file(path)
  end
end

local FILE_TOOLS = { Edit = true, Write = true, MultiEdit = true, NotebookEdit = true }

local function handle_event(sid, evt)
  local st = active[sid]
  if not st then return end
  local ok_u, ui = pcall(require, "claude.ui")
  if not ok_u then return end

  local t = evt.type
  if t == "system" and evt.subtype == "init" then
    if evt.session_id then
      st.session.claude_id = evt.session_id
      persist_pointer(st)
    end
  elseif t == "assistant" and evt.message then
    local msg = evt.message
    if msg.content then
      for _, block in ipairs(msg.content) do
        if block.type == "text" and block.text then
          ui.append_assistant_text(sid, block.text)
        elseif block.type == "tool_use" then
          local input = block.input or {}
          local path = abs_path(input.file_path)
          if path and FILE_TOOLS[block.name] then
            ensure_before(sid, path)
          end
          local summary
          local name = block.name or "tool"
          if name == "Bash" then
            summary = input.command or ""
          elseif name == "Grep" or name == "Glob" then
summary = input.pattern or ""
          elseif name == "Task" then
            summary = input.description or ""
          elseif name == "WebFetch" or name == "WebSearch" then
            summary = input.url or input.query or ""
          elseif name == "TodoWrite" then
            summary = "(todos)"
          elseif name == "Edit" or name == "MultiEdit" then
            summary = path or input.file_path or ""
          else
            summary = path or input.file_path or input.command or input.pattern or input.query or ""
          end
          summary = (summary or ""):gsub("\n", " ")
          if #summary > 200 then summary = summary:sub(1, 200) .. "…" end
          ui.append_tool_use(sid, name, summary)

          local diff_lines
          if name == "Edit" and input.old_string and input.new_string then
            diff_lines = {}
            for _, l in ipairs(vim.split(input.old_string, "\n", { plain = true })) do
              table.insert(diff_lines, "- " .. l)
            end
            for _, l in ipairs(vim.split(input.new_string, "\n", { plain = true })) do
              table.insert(diff_lines, "+ " .. l)
            end
          elseif name == "MultiEdit" and type(input.edits) == "table" then
            diff_lines = {}
            for i, e in ipairs(input.edits) do
              if i > 1 then table.insert(diff_lines, "@@") end
              for _, l in ipairs(vim.split(e.old_string or "", "\n", { plain = true })) do
                table.insert(diff_lines, "- " .. l)
              end
              for _, l in ipairs(vim.split(e.new_string or "", "\n", { plain = true })) do
                table.insert(diff_lines, "+ " .. l)
              end
            end
          elseif name == "Write" and input.content then
            diff_lines = {}
            for _, l in ipairs(vim.split(input.content, "\n", { plain = true })) do
              table.insert(diff_lines, "+ " .. l)
            end
          end
          if diff_lines and #diff_lines > 0 then
            ui.append_diff(sid, diff_lines)
          end
        end
      end
    end
  elseif t == "user" and evt.message then
    -- tool results, ignore content for now
  elseif t == "result" then
    flush_prompt(sid)
    ui.append_separator(sid)
  elseif t == "stream_event" then
    local e = evt.event
    if e and e.delta and e.delta.text then
      ui.append_assistant_text(sid, e.delta.text)
    end
  end
end

local function dispatch_line(sid, line)
  if line == "" then return end
  log("OUT", line)
  local ok, evt = pcall(vim.json.decode, line)
  if ok and type(evt) == "table" then
    handle_event(sid, evt)
  else
    log("PARSE_FAIL", line)
  end
end

local function on_stdout(sid, data)
  if not data then return end
  local st = active[sid]
  if not st then return end
  st.line_buf = st.line_buf or ""
  -- jobstart splits on \n: each callback gets list of lines; last element is partial continuation.
  for i, chunk in ipairs(data) do
    if i == 1 then
      st.line_buf = st.line_buf .. chunk
    else
      dispatch_line(sid, st.line_buf)
      st.line_buf = chunk
    end
  end
end

local function flush_line_buf(sid)
  local st = active[sid]
  if not st then return end
  if st.line_buf and st.line_buf ~= "" then
    dispatch_line(sid, st.line_buf)
    st.line_buf = ""
  end
end

function M.start_session()
  local id = store.uuid()
  local session = {
    id = id,
    started_at = os.time(),
    cwd = vim.fn.getcwd(),
    claude_id = nil,
    prompts = {},
  }
  active[id] = {
    session = session,
    line_buf = "",
    before_files = {},
    current_prompt = nil,
    job = nil,
  }
  return id
end

function M.attach_existing(session)
  active[session.id] = {
    session = session,
    line_buf = "",
    before_files = {},
    current_prompt = nil,
    job = nil,
  }
  return session.id
end

function M.resume_from_pointer()
  local ptr = store.read_pointer()
  if not ptr then return nil end
  local existing = ptr.session_id and store.load(ptr.session_id) or nil
  if existing then
    return M.attach_existing(existing)
  end
  -- session never wrote files; rebuild a thin session object so we can keep using claude_id
  local session = {
    id = ptr.session_id or store.uuid(),
    started_at = ptr.ts or os.time(),
    cwd = ptr.cwd or vim.fn.getcwd(),
    claude_id = ptr.claude_id,
    prompts = {},
  }
  return M.attach_existing(session)
end

function M.is_busy(sid)
  local st = active[sid]
  return st and st.job ~= nil
end

function M.send(sid, prompt_text, opts)
  opts = opts or {}
  local st = active[sid]
  if not st then return false, "no session" end
  if st.job then return false, "previous prompt still running" end

  local prompt_id = store.uuid()
  st.current_prompt = { id = prompt_id, text = prompt_text, ts = os.time(), files = {} }
  st.before_files = {}

  local cmd = { "claude", "-p", "--output-format", "stream-json", "--verbose" }
  if st.session.claude_id then
    table.insert(cmd, "--resume")
    table.insert(cmd, st.session.claude_id)
  end
  if skip_permissions then
    table.insert(cmd, "--dangerously-skip-permissions")
  end
  table.insert(cmd, prompt_text)

  local ok_u, ui = pcall(require, "claude.ui")
  if ok_u and not opts.skip_ui_prompt then ui.append_user_prompt(sid, prompt_text) end

  log("CMD", table.concat(cmd, " | "))

  st.job = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    on_stdout = function(_, data) on_stdout(sid, data) end,
    on_stderr = function(_, data)
      if not data then return end
      for _, l in ipairs(data) do
        if l ~= "" then
          log("ERR", l)
          vim.schedule(function()
            if ok_u then ui.append_stderr(sid, l) end
          end)
        end
      end
    end,
    on_exit = function(_, code)
      log("EXIT", code)
      flush_line_buf(sid)
      st.job = nil
      local was_cancelled = st.cancelled
      st.cancelled = false
      if was_cancelled then
        st.current_prompt = nil
        st.before_files = {}
        vim.schedule(function()
          if ok_u then ui.append_cancelled(sid) end
        end)
      else
        if st.current_prompt then
          flush_prompt(sid)
        end
        if code ~= 0 then
          vim.schedule(function()
            vim.notify("claude exited " .. tostring(code), vim.log.levels.ERROR)
          end)
        end
      end
      persist_pointer(st)
    end,
  })
  if st.job <= 0 then
    st.job = nil
    st.current_prompt = nil
    return false, "failed to spawn claude"
  end
  pcall(vim.fn.chanclose, st.job, "stdin")
  return true
end

function M.get_session(sid)
  local st = active[sid]
  return st and st.session or nil
end

function M.cancel(sid)
  local st = active[sid]
  if not st or not st.job then return false end
  st.cancelled = true
  pcall(vim.fn.jobstop, st.job)
  return true
end

function M.cancel_active()
  for sid, st in pairs(active) do
    if st.job then
      st.cancelled = true
      pcall(vim.fn.jobstop, st.job)
      return sid
    end
  end
  return nil
end

return M
