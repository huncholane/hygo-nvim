vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal"

---@type LazySpec
return {
  "rmagatti/auto-session",
  dependencies = { "folke/which-key.nvim" },
  lazy = false,
  config = function()
    local session = require("auto-session")
    session.setup({
      suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "~/Leet", "/tmp" },
    })

    -- Wait for other plugins for keymaps to register with which key
    vim.defer_fn(function()
      vim.keymap.set("n", "<leader>s", "", { desc = "Sessions" })
      -- Delete session and exit
      vim.keymap.set("n", "<leader>sd", function()
        session.delete_session()
        vim.cmd(":wqa!")
      end, { desc = "Delete Session" })
    end, 100)
  end,
}
