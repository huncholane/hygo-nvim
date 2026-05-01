local M = {}

local ns = vim.api.nvim_create_namespace("claude_changes")
local cfg = { highlight = true, blame = true }

function M.setup(opts)
  cfg.highlight = opts.highlight ~= false
  cfg.blame = opts.blame ~= false

  vim.api.nvim_set_hl(0, "ClaudeChange", { default = true, bg = "#3a2410" })
  vim.api.nvim_set_hl(0, "ClaudeChangeSign", { default = true, fg = "#e07b00" })
  vim.api.nvim_set_hl(0, "ClaudeBlame", { default = true, fg = "#7f5a2a", italic = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "BufEnter" }, {
    callback = function(args)
      M.apply_to_buf(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
    callback = function() M.refresh_all() end,
  })
end

local function qf_item_path(item)
  if item.filename and item.filename ~= "" then return item.filename end
  if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
    return vim.api.nvim_buf_get_name(item.bufnr)
  end
  return nil
end

local function collect_for_path(abs_path)
  local out = {}
  local items = vim.fn.getqflist()
  for _, item in ipairs(items) do
    local fname = qf_item_path(item)
    if fname and fname ~= "" then
      local p = vim.fn.fnamemodify(fname, ":p")
      if p == abs_path and item.lnum and item.lnum > 0 then
        local s = item.lnum
        local e = (item.end_lnum and item.end_lnum > 0) and item.end_lnum or s
        table.insert(out, { start = s, finish = e, prompt = item.text or "" })
      end
    end
  end
  return out
end

function M.apply_to_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not (cfg.highlight or cfg.blame) then return end
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
      local opts = {}
      if cfg.highlight then opts.line_hl_group = "ClaudeChange" end
      if cfg.blame and ln == s then
        local snippet = (h.prompt or ""):gsub("%s+", " "):sub(1, 80)
        opts.virt_text = { { "  ▏ " .. snippet, "ClaudeBlame" } }
        opts.virt_text_pos = "eol"
      end
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, ln, 0, opts)
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

return M
