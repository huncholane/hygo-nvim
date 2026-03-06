---@type LazySpec
return {
  dir = vim.fn.stdpath("config") .. "/claude-nvim",
  name = "claude",
  event = "VeryLazy",
  config = function()
    require("claude").setup({
      width = 100,
      skip_permissions = true
    })
  end,
}
