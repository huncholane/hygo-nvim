local M = {}

local state = {
  buf = nil,
  win = nil,
  width = 80,
  was_insert = true,
}

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
  local f = io.open(state_file(), "w")
  if f then
    f:write(M.is_open() and "open" or "closed")
    f:close()
  end
end

function M.load_state()
  local f = io.open(state_file(), "r")
  if not f then
    return false
  end
  local content = f:read("*a")
  f:close()
  return content == "open"
end

function M.setup(opts)
  state.width = opts.width or 80

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      M.save_state()
    end,
  })
end

function M.is_open()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

function M.open(cmd)
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
      vim.api.nvim_win_set_width(state.win, state.width)
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
  vim.api.nvim_win_set_width(state.win, state.width)

  vim.cmd("terminal " .. cmd)
  state.buf = vim.api.nvim_get_current_buf()

  vim.bo[state.buf].buflisted = false

  vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { buffer = state.buf, desc = "Claude: Focus left window" })
  vim.keymap.set(
    "t",
    "<C-j>",
    "<C-\\><C-n><C-d><cmd>startinsert<CR>",
    { buffer = state.buf, desc = "Claude: Scroll down" }
  )
  vim.keymap.set(
    "t",
    "<C-k>",
    "<C-\\><C-n><C-u><cmd>startinsert<CR>",
    { buffer = state.buf, desc = "Claude: Scroll up" }
  )
  vim.keymap.set("t", "<C-CR>", "\n", { buffer = state.buf, desc = "Claude: New line" })
  vim.keymap.set("t", "<C-c>", function()
    M.close()
  end, { buffer = state.buf, desc = "Claude: Close window" })

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
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    M.close()
    vim.api.nvim_buf_delete(state.buf, { force = true })
    state.buf = nil
  end
end

function M.send(text)
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
