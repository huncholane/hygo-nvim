require("lazy-bootstrap")

-- These plugins don't need individual files
local plugins = {
  { "nvim-telescope/telescope.nvim" },
  { "folke/tokyonight.nvim" },
  {
    "mason-org/mason.nvim",
    opts = {}
  },
  { "nvim-tree/nvim-web-devicons" },
  {
    "kawre/leetcode.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "tree-sitter/tree-sitter-html" },
    opts = {},
  },
  { "windwp/nvim-autopairs",      opts = {} },
  { "nvim-mini/mini.ai",          opts = {} },
  "tpope/vim-dadbod",
  "kristijanhusak/vim-dadbod-completion",
  "kristijanhusak/vim-dadbod-ui",
}

-- Load plugins from lua/plugins
for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lua/plugins")) do
  if file:sub(-4) == ".lua" then
    local mod_str = 'plugins.' .. file:sub(1, -5)
    local ok, mod = pcall(require, mod_str)
    if ok then
      table.insert(plugins, mod)
    end
  end
end

require("lazy").setup(plugins)
