require("lazy-bootstrap")

-- These plugins don't need individual files
local plugins = {
  { "ellisonleao/dotenv.nvim",      opts = {} },
  { "nvim-telescope/telescope.nvim" },
  { "folke/tokyonight.nvim" },
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  "tpope/vim-dispatch",
  { "nvim-tree/nvim-web-devicons" },
  { "windwp/nvim-autopairs",             opts = {} },
  { "windwp/nvim-ts-autotag",            opts = {} },
  { "neovim/nvim-lspconfig" },
  { "saecki/crates.nvim",                tag = "stable", opts = {} },
  { "axkirillov/telescope-changed-files" },
}

-- Load plugins from lua/plugins
for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lua/plugins")) do
  if file:sub(-4) == ".lua" then
    local mod_str = "plugins." .. file:sub(1, -5)
    local ok, mod = pcall(require, mod_str)
    if ok then
      table.insert(plugins, mod)
    end
  end
end

require("lazy").setup(plugins)
