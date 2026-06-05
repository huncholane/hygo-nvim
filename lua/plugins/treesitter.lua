---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.config").setup({
      ensure_installed = {
        "c",
        "lua",
        "vim",
        "vimdoc",
        "json",
        "python",
        "rust",
        "typescript",
        "markdown",
        "bash",
        "http",
        "astro",
      },
      highlight = {
        enable = true,
      },
      sync_install = false,
      auto_install = true,
      ignore_install = {},
      modules = {},
    })
  end,
}
