vim.cmd([[
comp rust_verbose
TSBufEnable highlight
]])
require("nvim-autopairs").remove_rule("`")
require("nvim-autopairs").remove_rule("'")

-- Fill the current match or struct
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.title:match("Fill")
    end,
    apply = true,
  })
end, { desc = "Fill" })

-- Remove all unused imports
vim.keymap.set("n", "<leader>i", function()
  -- initial cursor position
  local pos = vim.api.nvim_win_get_cursor(0)

  -- remove unused imports
  vim.lsp.buf.code_action({
    range = {
      ["start"] = { 1, 1 },
      ["end"] = { vim.api.nvim_buf_line_count(0), 1 },
    },
    filter = function(action)
      return action.title:match("Remove all unused imports")
    end,

    apply = true,
  })

  -- wait brief moment to restore cursor position
  vim.defer_fn(function()
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end, 50)
end)
