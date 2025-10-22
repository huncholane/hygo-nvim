---@type LazySpec
return {
  "folke/which-key.nvim",
  config = function()
    require("which-key").add({
      { "<leader>w", proxy = "<c-w>", group = "windows" },
    })
  end,
}
