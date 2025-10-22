---@type LazySpec
return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    options = {
      theme = "gruvbox",
      globalstatus = true,
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        {
          function()
            local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
            if not handle then return "" end
            local result = handle:read("*a")
            handle:close()
            if result == "" then return "" end
            local name = vim.fn.fnamemodify(result:gsub("\n", ""), ":t")
            return " " .. name
          end,
          -- no need for cond = …, just check inside function
          color = { fg = "#f7768e", gui = "bold" },
        },
        "branch",
        "diff",
      },
      lualine_c = {
        {
          function()
            return " " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          end,
          color = { fg = "#7aa2f7", gui = "bold" },
        },
        { "filename", path = 1 },
      },
      lualine_x = {
        "encoding",
        "fileformat",
        {
          function()
            local mp = vim.o.makeprg or ""
            if mp == "" then return "" end
            local exe = vim.fn.fnamemodify(vim.split(mp, " ")[1], ":t")
            return "⚙️ " .. exe
          end,
        },
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}
