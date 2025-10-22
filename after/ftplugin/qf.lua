vim.keymap.set("n", "n", ":cnext<cr> :copen<cr>", { desc = "Next", buffer = true })
vim.keymap.set("n", "p", ":cprev<cr> :copen<cr>", { desc = "Prev", buffer = true })
vim.keymap.set("n", "q", ":q<cr>", { desc = "Close", buffer = true, nowait = true })
