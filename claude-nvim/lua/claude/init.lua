local M = {}

local ui = require("claude.ui")
local runner = require("claude.runner")
local highlights = require("claude.highlights")
local pickers = require("claude.pickers")
local edit = require("claude.edit")

---@class ClaudeConfig
local defaults = {
  --- Width of the Claude panel (default: 80)
  width = 80,
  --- Add --dangerously-skip-permissions flag to all claude commands (default: false)
  skip_permissions = false,
  --- Highlight claude-changed lines like gitsigns (default: true)
  highlight = true,
  --- Inline blame: show prompt text on changed lines (default: true)
  blame = true,
  --- Write raw stream events + cmd + exit codes to <data>/claude-nvim/debug.log
  debug = false,
}

--- Setup the Claude CLI wrapper plugin.
---@param opts? ClaudeConfig
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  ui.setup(opts)
  runner.setup(opts)
  highlights.setup(opts)
  edit.setup(opts)

  vim.keymap.set("n", "<leader>c", "", { desc = "Claude" })

  vim.keymap.set("n", "<leader>cc", ui.cancel_current, { desc = "Claude: Cancel current prompt" })
  vim.keymap.set("n", "<leader>ct", ui.toggle, { desc = "Claude: Toggle panel" })
  vim.keymap.set("n", "<leader>cn", ui.start_new, { desc = "Claude: New session" })
  vim.keymap.set("n", "<leader>cr", ui.resume_last, { desc = "Claude: Resume last session" })
  vim.keymap.set("n", "<leader>cs", pickers.sessions_picker, { desc = "Claude: Sessions picker" })
  vim.keymap.set("n", "<leader>cq", pickers.prompts_picker, { desc = "Claude: Prompts → quickfix" })
  vim.keymap.set("n", "<leader>cl", pickers.qf_last, { desc = "Claude: Last prompt → quickfix" })
  vim.keymap.set("n", "<leader>cp", ui.open_prompt_keep_focus, { desc = "Claude: Prompt (keep focus)" })

  vim.keymap.set("v", "<leader>c", function()
    edit.prompt_visual()
  end, { desc = "Claude: Edit selection with prompt" })

  vim.keymap.set("v", "<leader>p", function()
    ui.prompt_visual_chat()
  end, { desc = "Claude: Chat with selection as context" })
end

return M
