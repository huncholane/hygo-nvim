local M = {}

local store = require("claude.store")
local ns = vim.api.nvim_create_namespace("claude_changes")
local cfg = { highlight = true, blame = true }

function M.setup(opts)
  cfg.highlight = opts.highlight ~= false
  cfg.blame = opts.blame ~= false

  vim.api.nvim_set_hl(0, "ClaudeChange", { default = true, bg = "#3a2410" })
  vim.api.nvim_set_hl(0, "ClaudeChangeSign", { default = true, fg = "#e07b00" })
  vim.api.nvim_set_hl(0, "ClaudeBlame", { default = true, fg = "#7f5a2a", italic = true })

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    callback = function(args)
      M.apply_to_buf(args.buf)
    end,
  })
end

local function collect_for_path(abs_path)
  local out = {}
  for _, p in ipairs(store.all_prompts()) do
    for _, f in ipairs(p.files or {}) do
      if f.path == abs_path then
        for _, h in ipairs(f.hunks or {}) do
          table.insert(out, {
            start = h.start,
            finish = h.finish,
            prompt = p.text or "",
            ts = p.ts or 0,
          })
        end
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
