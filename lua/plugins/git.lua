---@type LazySpec
return {
  "lewis6991/gitsigns.nvim",
  dependencies = { { "tpope/vim-fugitive" } },
  event = "VeryLazy",
  config = function()
    local gitsigns = require("gitsigns")
    gitsigns.setup()
    require("extensions.git-extensions").setup()
  end,
}
