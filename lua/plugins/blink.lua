local function lspkind_config()
  local lspKindConfig = require("lspkind")
  lspKindConfig.init({
    symbol_map = {
      Boolean = "  Boolean",
      Character = "󰬴  Character",
      Class = "  Class",
      Color = "  Color",
      Constant = "󱊈  Constant",
      Constructor = "  Constructor",
      Enum = "  Enum",
      EnumMember = "  EnumMember",
      Event = "  Event",
      Field = "  Field",
      File = "  File",
      Folder = "  Folder",
      Function = "󰡱  Function",
      Interface = "  Interface",
      Keyword = "  Keyword",
      Method = "󰡱  Method",
      Module = "󰕳  Module",
      Number = "󰒾  Number",
      Operator = "[Ψ] Operator",
      Parameter = "[] Parameter",
      Property = "[ﭬ] Property",
      Reference = "[] Reference",
      Snippet = "  Snippet",
      String = "[] String",
      Struct = " Struct",
      Text = "󰊄  Text",
      TypeParameter = "[] TypeParameter",
      Unit = "[] Unit",
      Value = "  Value",
      Variable = "󱄑  Variable",
      Copilot = "",
    },
  })
end

---@type LazySpec
return {
  "saghen/blink.cmp",
  dependencies = {
    "rafamadriz/friendly-snippets",
    -- "tamago324/nlsp-settings.nvim",
    { "onsails/lspkind.nvim", config = lspkind_config },
  },
  build = "cargo build --release",
  opts = {
    cmdline = { enabled = false },
    sources = {
      default = { "lsp", "buffer", "snippets", "path" },
      per_filetype = {
        sql = { "dadbod", "buffer" },
      },
      providers = {
        path = {
          opts = {
            get_cwd = function(_)
              return vim.fn.getcwd()
            end,
          },
      },
        dadbod = { module = "vim_dadbod_completion.blink" },
      },
    },
    completion = {
      menu = {
        auto_show = true,
        draw = {
          components = {
            kind_icon = {
              text = function(ctx)
                return require("lspkind").symbolic(ctx.kind, {
                  mode = "symbol",
                  preset = "codicons",
                })
              end,
            },
          },
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 0,
      },
      list = { selection = { preselect = false, auto_insert = true } },
    },
  },
}
