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
          require("otter").activate({ "html" }, true, true)
          -- Trigger FileType on otter's hidden HTML buffer so the HTML LSP auto-attaches
          vim.defer_fn(function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if
                  vim.bo[buf].filetype == "html"
                  and vim.api.nvim_buf_get_name(buf):match("%.otter%.html$")
              then
                vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
                break
              end
            end
          end, 200)
        end, 200)
      end,
    })
  end,
}
