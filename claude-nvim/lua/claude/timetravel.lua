local M = {}

local store = require("claude.store")

local cursor = nil

local function all_asc()
  local desc = store.all_prompts()
  local out = {}
  for i = #desc, 1, -1 do table.insert(out, desc[i]) end
  return out
end

local function ensure_cursor()
  if cursor == nil then
    cursor = #all_asc()
  end
end

local function write_file(path, content)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(content or "")
  f:close()
  return true
end

local function reload_buffers(path)
  local abs = vim.fn.fnamemodify(path, ":p")
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      local n = vim.api.nvim_buf_get_name(b)
      if n ~= "" and vim.fn.fnamemodify(n, ":p") == abs then
        if not vim.bo[b].modified then
          pcall(vim.api.nvim_buf_call, b, function() vim.cmd("edit!") end)
        else
          vim.notify("claude: buffer " .. n .. " has unsaved edits — not reloaded", vim.log.levels.WARN)
        end
      end
    end
  end
end

local function preview(p)
  return ((p.text or ""):gsub("%s+", " ")):sub(1, 50)
end

function M.undo()
  ensure_cursor()
  local prompts = all_asc()
  if cursor <= 0 then
    vim.notify("claude: nothing to undo", vim.log.levels.WARN)
    return
  end
  local p = prompts[cursor]
  local applied = 0
  for _, f in ipairs(p.files or {}) do
    if f.before_content ~= nil then
      if write_file(f.path, f.before_content) then
        applied = applied + 1
        reload_buffers(f.path)
      end
    end
  end
  cursor = cursor - 1
  if applied == 0 then
    vim.notify("claude: prompt has no before-state (older schema)", vim.log.levels.WARN)
  else
    vim.notify("claude: undid '" .. preview(p) .. "' (" .. applied .. " files)")
  end
end

function M.redo()
  ensure_cursor()
  local prompts = all_asc()
  if cursor >= #prompts then
    vim.notify("claude: nothing to redo", vim.log.levels.WARN)
    return
  end
  local p = prompts[cursor + 1]
  local applied = 0
  for _, f in ipairs(p.files or {}) do
    if f.after_content ~= nil then
      if write_file(f.path, f.after_content) then
        applied = applied + 1
        reload_buffers(f.path)
      end
    end
  end
  cursor = cursor + 1
  if applied == 0 then
    vim.notify("claude: prompt has no after-state (older schema)", vim.log.levels.WARN)
  else
    vim.notify("claude: redid '" .. preview(p) .. "' (" .. applied .. " files)")
  end
end

function M.bump()
  ensure_cursor()
  cursor = (cursor or 0) + 1
end

function M.reset()
  cursor = nil
end

return M
