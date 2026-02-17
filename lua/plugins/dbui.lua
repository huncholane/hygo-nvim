---@type LazySpec
return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      "tpope/vim-dadbod",
      "ellisonleao/dotenv.nvim",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      vim.g.db = vim.env.DATABASE_URL

      local group = vim.api.nvim_create_augroup("dbui", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "sql",
        group = group,
        callback = function()
          vim.cmd("Dotenv")
          vim.keymap.set("n", "<leader>r", ":DB < %<CR>", { buffer = true, desc = "Run File" })
          vim.keymap.set("v", "<leader>r", ":DB<CR>", { buffer = true, desc = "Run File" })
        end,
      })
    end,
  },
}
