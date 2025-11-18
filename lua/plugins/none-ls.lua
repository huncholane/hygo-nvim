---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  dependencies = {
    { "nvimtools/none-ls-extras.nvim" },
  },
  -- dependencies = {
  --   { dir = "~/code/contributions/none-ls-extras.nvim" },
  -- },
  config = function()
    local null_ls = require("null-ls")

    null_ls.setup({
      sources = {
        require("null-ls.builtins.formatting.prettier").with({
          filetypes = { "sh", "env" },
        }),
        require("none-ls.formatting.mbake"),
        require("null-ls.builtins.diagnostics.checkmake"),
        require("null-ls.builtins.formatting.isort"),
        require("null-ls.builtins.formatting.isort"),
        require("none-ls.formatting.taplo"),
        require("null-ls.builtins.formatting.black"),
        require("null-ls.builtins.formatting.stylua"),
        require("null-ls.builtins.diagnostics.hadolint"),
        require("null-ls.builtins.formatting.djlint"),
      },
    })
  end,
}
