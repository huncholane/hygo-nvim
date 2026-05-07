-- Minimal init for plenary busted tests.
-- Run: nvim --headless -u tests/minimal_init.lua \
--   -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

local plenary = vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")
vim.opt.rtp:prepend(plenary)

local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

vim.cmd("runtime plugin/plenary.vim")
