vim.cmd([[
comp rust_verbose
TSBufEnable highlight
]])
require("nvim-autopairs").remove_rule("`")
require("nvim-autopairs").remove_rule("'")
