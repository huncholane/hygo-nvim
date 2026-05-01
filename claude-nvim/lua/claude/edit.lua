local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local ns = vim.api.nvim_create_namespace("claude_edit")
local skip_permissions = false

function M.setup(opts)
  if opts and opts.skip_permissions then
    skip_permissions = true
  end
end

local function strip_fences(text)
  local lines = vim.split(text, "\n", { plain = true })
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end
  if #lines >= 2 and lines[1]:match("^```") then
    table.remove(lines, 1)
    if lines[#lines] and lines[#lines]:match("^```%s*$") then
      table.remove(lines)
    end
  end
  return lines
end

local function start_spinner(buf, row)
  local idx = 1
  local function virt(i)
    return { { " " .. spinner_frames[i] .. " claude…", "Comment" } }
  end
  local ok, mark = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
    virt_text = virt(idx),
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
  if not ok then return function() end end

  local timer = vim.uv.new_timer()
  timer:start(80, 80, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      timer:stop(); timer:close()
      return
    end
    idx = idx % #spinner_frames + 1
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
      id = mark,
      virt_text = virt(idx),
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
  end))

  return function()
    if not timer:is_closing() then
      timer:stop(); timer:close()
    end
    pcall(vim.api.nvim_buf_del_extmark, buf, ns, mark)
  end
end

local function run_claude(prompt, selection, on_done)
  local full = string.format(
    "Apply the following instruction to the code below. Output ONLY the resulting replacement code. No explanation, no commentary, no markdown code fences.\n\nInstruction:\n%s\n\nCode:\n%s",
    prompt, selection
  )
  local cmd = { "claude", "-p", full }
  if skip_permissions then
    table.insert(cmd, "--dangerously-skip-permissions")
  end
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(out)
    if out.code ~= 0 then
      on_done(nil, (out.stderr ~= "" and out.stderr) or ("claude exited " .. tostring(out.code)))
    else
      on_done(out.stdout or "", nil)
    end
  end))
end

function M.prompt_visual()
  -- Capture selection text + range
  local old_reg = vim.fn.getreg('"')
  local old_regtype = vim.fn.getregtype('"')
  vim.cmd('noautocmd normal! "vy')
  local selection = vim.fn.getreg("v")
  vim.fn.setreg('"', old_reg, old_regtype)

  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  local target_buf = vim.api.nvim_get_current_buf()
  local start_row = s[2] - 1
  local end_row = e[2] - 1

  if selection == nil or selection == "" then
    vim.notify("claude: empty selection", vim.log.levels.WARN)
    return
  end

  -- Floating popup
  local pop_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[pop_buf].bufhidden = "wipe"
  vim.bo[pop_buf].filetype = "markdown"

  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.6)))
  local height = 8
  local pop_win = vim.api.nvim_open_win(pop_buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Claude prompt — <C-s> apply  <C-c> cancel ",
    title_pos = "center",
  })

  vim.cmd("startinsert")

  local closed = false
  local function close_popup()
    if closed then return end
    closed = true
    pcall(vim.cmd, "stopinsert")
    if vim.api.nvim_win_is_valid(pop_win) then
      vim.api.nvim_win_close(pop_win, true)
    end
  end

  local function apply()
    if closed then return end
    local lines = vim.api.nvim_buf_get_lines(pop_buf, 0, -1, false)
    local prompt = table.concat(lines, "\n")
    close_popup()
    if prompt:match("^%s*$") then
      vim.notify("claude: empty prompt", vim.log.levels.WARN)
      return
    end

    if not vim.api.nvim_buf_is_valid(target_buf) then return end
    local stop_spin = start_spinner(target_buf, start_row)

    run_claude(prompt, selection, function(stdout, err)
      stop_spin()
      if err then
        vim.notify("claude: " .. err, vim.log.levels.ERROR)
        return
      end
      if not vim.api.nvim_buf_is_valid(target_buf) then return end
      local out_lines = strip_fences(stdout or "")
      if #out_lines == 0 then
        vim.notify("claude: empty response", vim.log.levels.WARN)
        return
      end
      vim.api.nvim_buf_set_lines(target_buf, start_row, end_row + 1, false, out_lines)
    end)
  end

  local km = { buffer = pop_buf, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", apply, km)
  vim.keymap.set({ "n", "i" }, "<C-c>", close_popup, km)
  vim.keymap.set("n", "q", close_popup, km)
  vim.keymap.set("n", "<Esc>", close_popup, km)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = pop_buf,
    once = true,
    callback = close_popup,
  })
end

return M
