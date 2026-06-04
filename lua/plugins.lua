require("lazy-bootstrap")

-- These plugins don't need individual files
local plugins = {
  { "ellisonleao/dotenv.nvim", opts = {} },
  { "folke/tokyonight.nvim" },
  { "mg979/vim-visual-multi" },
  {
    "3rd/image.nvim",
    opts = {
      backend = "sixel",
      processor = "magick_cli",
      integrations = {
        -- Disabled: sixel rendering under tmux throws on every cursor move
        -- through a markdown file. Use :MarkdownPreview for rendered READMEs.
        markdown = {
          enabled = false,
          only_render_image_at_cursor = true,
          only_render_image_at_cursor_mode = "popup",
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  "tpope/vim-dispatch",
  { "nvim-tree/nvim-web-devicons" },
  { "windwp/nvim-ts-autotag",            event = "InsertEnter", opts = {} },
  { "neovim/nvim-lspconfig" },
  { "saecki/crates.nvim",                tag = "stable",        opts = {} },
  { "axkirillov/telescope-changed-files" },
  { "armannikoyan/rusty" },
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
