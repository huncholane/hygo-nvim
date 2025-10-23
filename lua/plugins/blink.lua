---@type LazySpec
return {
  "saghen/blink.cmp",
  dependencies = { "rafamadriz/friendly-snippets" },
  build = "cargo build --release",
  opts = {
    cmdline = { enabled = false },
    sources = {
      per_filetype = {
        sql = { "dadbod" }
      },
      providers = {
        dadbod = { module = "vim_dadbod_completion.blink" }
      }
    }
  },
}
