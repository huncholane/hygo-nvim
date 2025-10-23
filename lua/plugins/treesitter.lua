---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  branch = 'master',
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "c", "lua", "vim", "vimdoc", "json", "python", "rust", "typescript", "markdown", "bash", "http" },
      highlight = {
        enable = true
      },
      sync_install = false,
      auto_install = true,
      ignore_install = {},
      modules = {}
    })
  end
}
