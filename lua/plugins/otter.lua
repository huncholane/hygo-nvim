---@type LazySpec
return {
  "jmbuhr/otter.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {},
  config = function()
    require("otter").setup({})

    vim.api.nvim_create_autocmd("filetype", {
      pattern = "rust",
      callback = function()
        -- Activate otter.nvim for HTML inside `// html` commented raw string literals
        vim.defer_fn(function()
          require("otter").activate({ "html", "sql" }, true, true)
        end, 200)
      end,
    })
  end,
}
