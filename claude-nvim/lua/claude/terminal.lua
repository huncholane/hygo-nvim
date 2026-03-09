local M = {}

local width = 80

---@type table<number, { buf: number?, win: number?, was_insert: boolean }>
local tabs = {}

local function get_state()
  local tab = vim.api.nvim_get_current_tabpage()
  if not tabs[tab] then
    tabs[tab] = { buf = nil, win = nil, was_insert = true }
  end
  return tabs[tab]
end

local function state_dir()
  local dir = vim.fn.stdpath("data") .. "/claude-sessions"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function state_file()
  local cwd = vim.fn.getcwd():gsub("/", "%%")
  return state_dir() .. "/" .. cwd
end

function M.save_state()
  local any_open = false
  for _, s in pairs(tabs) do
    if s.win and vim.api.nvim_win_is_valid(s.win) then
      any_open = true
      break
    end
  end
  local f = io.open(state_file(), "w")
  if f then
    f:write(any_open and "open" or "closed")
    f:close()
  end
end

function M.load_state()
  local f = io.open(state_file(), "r")
  if not f then return false end
  local content = f:read("*a")
  f:close()
  return content == "open"
end

function M.setup(opts)
  width = opts.width or 80

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.save_state()
    end,
  })
end

function M.is_open()
  local state = get_state()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function setup_keymaps(buf)
  vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { buffer = buf, desc = "Claude: Focus left window" })
  vim.keymap.set("t", "<C-k>", "<C-\\><C-n>", { buffer = buf, desc = "Claude: Normal mode" })
  vim.keymap.set("t", "<C-CR>", "\n", { buffer = buf, desc = "Claude: New line" })
end

function M.open(cmd)
  local state = get_state()

  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    if state.was_insert then
      vim.cmd("startinsert")
    end
    return
  end

  -- Reuse existing buffer if it's still valid and job is running
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    local chan = vim.bo[state.buf].channel
    if chan and chan > 0 and vim.fn.jobwait({ chan }, 0)[1] == -1 then
      vim.cmd("botright vsplit")
      state.win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(state.win, state.buf)
      vim.api.nvim_win_set_width(state.win, width)
      if state.was_insert then
        vim.cmd("startinsert")
      end
      return
    end
    -- Job is dead, clean up the buffer
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end

  -- Create new terminal
  vim.cmd("botright vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(state.win, width)

  vim.cmd("terminal " .. cmd)
  state.buf = vim.api.nvim_get_current_buf()

  vim.bo[state.buf].buflisted = false

  setup_keymaps(state.buf)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.buf,
    callback = function()
      state.was_insert = (vim.fn.mode() == "t")
    end,
  })

  state.was_insert = true
  vim.cmd("startinsert")
end

function M.close()
  local state = get_state()
  if M.is_open() then
    vim.api.nvim_win_hide(state.win)
    state.win = nil
  end
end

function M.toggle(cmd)
  if M.is_open() then
    M.close()
  else
    M.open(cmd)
  end
end

function M.kill()
  local state = get_state()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    M.close()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
end

function M.send(text)
  local state = get_state()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return false
  end

  local chan = vim.bo[state.buf].channel
  if chan == 0 then
    return false
  end

  vim.api.nvim_chan_send(chan, text)
  return true
end

return M
