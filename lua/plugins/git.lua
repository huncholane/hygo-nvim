---@type LazySpec
return {
  "lewis6991/gitsigns.nvim",
  dependencies = { { "tpope/vim-fugitive" } },
  event = "VeryLazy",
  config = function()
    local gitsigns = require("gitsigns")
    gitsigns.setup({
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
        virt_text_pos = "eol",
      },
    })
    require("extensions.git-extensions").setup()
  end,
}
