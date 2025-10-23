---@type LazySpec
return {
  "saghen/blink.cmp",
  dependencies = { "rafamadriz/friendly-snippets" },
  build = "cargo build --release",
  opts = {
    cmdline = { enabled = false },
    sources = {
      default = { "lsp", "buffer", "snippets", "path" },
      per_filetype = {
        sql = { "dadbod", "buffer" }
      },
      providers = {
        dadbod = { module = "vim_dadbod_completion.blink" }
      }
    }
  },
}
