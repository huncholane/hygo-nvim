---@type LazySpec
return {
  "rest-nvim/rest.nvim",
  dependencies = {
    { "j-hui/fidget.nvim" },
    { "nvim-neotest/nvim-nio" },
    {
      "nvim-treesitter/nvim-treesitter",
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        table.insert(opts.ensure_installed, "http")
      end,
    }
  },
  ft = { "http" },
  keys = {
  }
}
