require("plugins")
require("options")
require("functions")
require("commands")
require("keymaps")

-- require local config if possible
pcall(require, ".nvim")
