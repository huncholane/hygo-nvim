local M = {}

local ns = vim.api.nvim_create_namespace("qf_line_highlights")
local cfg = { hl_group = "QfLineHl" }

local function qf_item_path(item)
  if item.filename and item.filename ~= "" then return item.filename end
  if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
    return vim.api.nvim_buf_get_name(item.bufnr)
  end
  return nil
end

local function collect_for_path(abs_path)
  local out = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    local fname = qf_item_path(item)
    if fname and fname ~= "" then
      local p = vim.fn.fnamemodify(fname, ":p")
      if p == abs_path and item.lnum and item.lnum > 0 then
        local s = item.lnum
        local e = (item.end_lnum and item.end_lnum > 0) and item.end_lnum or s
        table.insert(out, { start = s, finish = e })
      end
    end
  end
  return out
end

function M.apply_to_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return end
  if vim.bo[buf].buftype ~= "" then return end
  local abs = vim.fn.fnamemodify(name, ":p")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local hunks = collect_for_path(abs)
  if #hunks == 0 then return end
  local lc = vim.api.nvim_buf_line_count(buf)
  for _, h in ipairs(hunks) do
    local s = math.max(0, (h.start or 1) - 1)
    local e = math.min(lc - 1, (h.finish or h.start or 1) - 1)
    if e < s then e = s end
    for ln = s, e do
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, ln, 0, { line_hl_group = cfg.hl_group })
    end
  end
end

function M.refresh_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      M.apply_to_buf(b)
    end
  end
end

function M.setup(opts)
  opts = opts or {}
  if opts.hl_group then cfg.hl_group = opts.hl_group end

  vim.api.nvim_set_hl(0, "QfLineHl", { default = true, bg = "#3a2410" })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufEnter" }, {
    callback = function(args) M.apply_to_buf(args.buf) end,
  })

  vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
    callback = function() M.refresh_all() end,
  })

  -- Detect qflist changes from any source (Lua setqflist by telescope/LSP/etc.).
  local last_tick = -1
  vim.api.nvim_create_autocmd({ "CursorHold", "WinEnter", "BufWinEnter", "FocusGained" }, {
    callback = function()
      local tick = (vim.fn.getqflist({ changedtick = 0 }) or {}).changedtick or 0
      if tick ~= last_tick then
        last_tick = tick
        M.refresh_all()
      end
    end,
  })
end

return M
