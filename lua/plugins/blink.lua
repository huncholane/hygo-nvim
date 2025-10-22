---@type LazySpec
return {
  "saghen/blink.cmp",
  dependencies = { "rafamadriz/friendly-snippets" },
  build = "cargo build --release",
  opts = { cmdline = { enabled = false } },
}
