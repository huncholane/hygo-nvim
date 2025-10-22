vim.keymap.set("n", "q", ":b#<cr>", { buffer = true, nowait = true })
vim.keymap.set("n", "_", ":exe 'Explore'.getcwd()<cr>", { buffer = true, nowait = true })
