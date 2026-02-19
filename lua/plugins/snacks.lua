---@type LazySpec
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  config = function()
    local Snacks = require("snacks")
    Snacks.setup({})
    vim.defer_fn(function()
      vim.keymap.set("n", "<leader>li", function()
        Snacks.picker.lsp_config()
      end, { desc = "Lsp Info" })
    end, 100)
  end,
}
