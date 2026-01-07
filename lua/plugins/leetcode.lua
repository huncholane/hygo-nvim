---@type LazySpec
return {
  "kawre/leetcode.nvim",
  dependencies = { "MunifTanjim/nui.nvim", "tree-sitter/tree-sitter-html", "folke/which-key.nvim" },
  config = function()
    local leet = require("leetcode")
    require("leetcode").setup({
      lang = "rust",
      hooks = {
        ---@type fun()[]
        ["enter"] = {
          function()
            -- vim.cmd("%bd")
            -- require("auto-session").disable_autosave()
          end,
        },
      },
    })
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("leet", { clear = true }),
      pattern = { "leetcode.nvim" },
      callback = function()
        vim.keymap.set("n", "<leader>s", "<cmd>Leet submit<cr>", { desc = "Submit" })
        vim.keymap.set("n", "<leader>t", "<cmd>Leet test<cr>", { desc = "Test" })
        vim.keymap.set("n", "<leader>l", "<cmd>Leet list<cr>", { desc = "List" })
      end,
    })
  end,
}
