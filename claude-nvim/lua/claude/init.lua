local M = {}

local terminal = require("claude.terminal")
local session = require("claude.session")
local edit = require("claude.edit")

---@class ClaudeConfig
local defaults = {
  --- Width of the Claude terminal split (default: 80)
  width = 80,
  --- Add --dangerously-skip-permissions flag to all claude commands (default: false)
  skip_permissions = false,
  --- Restore Claude terminal on nvim startup if it was open last session (default: false)
  open_on_start = false,
}

--- Setup the Claude CLI wrapper plugin.
---@param opts? ClaudeConfig
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  terminal.setup(opts)
  session.setup(opts)
  edit.setup(opts)

  vim.keymap.set("n", "<leader>c", "", { desc = "Claude" })

  -- Toggle claude panel (resumes last session)
  vim.keymap.set("n", "<leader>ct", session.continue, { desc = "Claude: Toggle panel" })

  -- Visual <leader>c → prompt popup that edits selection in place via claude -p
  vim.keymap.set("v", "<leader>c", function()
    edit.prompt_visual()
  end, { desc = "Claude: Edit selection with prompt" })

  -- Send current buffer to claude
  vim.keymap.set("n", "<leader>cb", function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local content = table.concat(lines, "\n")
    local filename = vim.fn.expand("%:t")

    if not terminal.is_open() then
      session.continue()
      vim.defer_fn(function()
        terminal.send("Here is " .. filename .. ":\n\n" .. content .. "\n")
      end, 500)
    else
      terminal.send("Here is " .. filename .. ":\n\n" .. content .. "\n")
    end
  end, { desc = "Claude: Send buffer" })

  -- New session
  vim.keymap.set("n", "<leader>cn", session.new, { desc = "Claude: New session" })

  -- Resume picker
  vim.keymap.set("n", "<leader>cr", session.resume, { desc = "Claude: Resume session picker" })

  -- Restore claude terminal on start
  if opts.open_on_start and terminal.load_state() then
    vim.defer_fn(function()
      session.continue()
    end, 100)
  end
end

return M
