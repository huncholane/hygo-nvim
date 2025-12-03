local function easymap(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc })
end
--leader
easymap("n", "<leader>k", ":SafeBD<cr>", "Close Buffer")
easymap("n", "<leader>b", ":LastFile<cr>", "Last File")
easymap("n", "<leader>q", ":silent! wa! | silent! qa!<cr>", "Quit")
easymap("n", "<leader>;", "q:", "Elite Cmd")
easymap("n", "<leader>f", ":Format<cr>", "Format")
easymap("n", "<leader>h", ":nohl<cr>", "Remove Highlights")
easymap("n", "<leader><Space>", ":Telescope find_files<cr>", "Files")
easymap("n", "<leader>l", ":<C-p><cr>", "Last Command")
easymap("n", "<leader>/", ":Telescope live_grep<cr>", "Live Grep")
easymap("n", "<leader>,", ":Telescope current_folder<cr>", "Search Current Folder")
easymap("n", "<leader>m", ':exe "resize ".float2nr(&lines*0.8)<cr>', "80% Window")
easymap("n", "<leader>s", ":Scratch<cr>", "Scratch")
easymap("n", "<leader>g", ":Telescope git_bcommits<cr>", "Buffer Commits")
easymap("n", "<leader>d", ":Telescope git_status<cr>", "Git Diff")
easymap("n", "<leader>.", ":Telescope all_files<cr>", "All Files")
for i = 1, 9 do
  easymap("n", "<leader>" .. i, i .. "gt", "Tab " .. i)
end

--quickfix
easymap("n", "<leader>c", "", "Quick Fix")
easymap("n", "<leader>cn", ":cnext<cr>", "Next")
easymap("n", "<leader>cp", ":cprev<cr>", "Prev")
easymap("n", "<leader>ct", ":ToggleClist<cr>", "Toggle")
easymap("n", "<leader>cq", ":cclose<cr>", "Close")
easymap("n", "<leader>co", ":copen<cr>", "Open")
easymap("n", "<leader>cc", ":cexpr []<cr>", "Clear")

--telescope
easymap("n", "<leader>t", "", "Telescope")
easymap("n", "<leader>ts", ":Telescope treesitter<cr>", "Treesitter")

--fold
easymap("n", "<leader>z", "", "Fold")
easymap("n", "<leader>zt", ":TreeSitterFold<cr>", "Treesitter")
easymap("n", "<leader>zi", ":IndentFold<cr>", "Indent")
easymap("n", "<leader>zs", ":SyntaxFold<cr>", "Syntax")

--windows
easymap({ "i", "n" }, "<C-h>", "<C-w>h")
easymap({ "i", "n" }, "<C-j>", "<C-w>j")
easymap({ "i", "n" }, "<C-k>", "<C-w>k")
easymap({ "i", "n" }, "<C-l>", "<C-w>l")
for i = 1, 9 do
  easymap("n", "<leader>w" .. i, ":Resize " .. i .. "0<cr>", "Resize " .. i .. "0%")
end
easymap("n", "<leader>w0", ":Resize 100<cr>", "Resize 100%")

---gotos
easymap("n", "gd", vim.lsp.buf.definition, "Goto Definition")
easymap({ "n", "v" }, "gy", '"+y', "System Clipboard Copy")
easymap({ "n", "v" }, "gp", '"+p', "System Clipboard Paste")
easymap("n", "gs", "<cmd>EditCurrentFiletype<cr>", "Filetype Settings")
easymap("n", "gm", "q:?make<cr><cr>", "Last Make")
easymap("n", "g;", "m'A;<esc>`'", "Append Colon")
easymap("n", "g,", "m'A,<esc>`'", "Append Comma")
easymap("n", "gl", "", "LSP")
easymap("n", "glt", ":ToggleDiagnostics<cr>", "Toggle")

---quickfix
easymap("n", "gq", "", "Quickfix")
easymap("n", "gql", vim.diagnostic.setqflist, "LSP")
easymap("n", "gqn", vim.diagnostic.goto_next, "Next Diagnostic")
easymap("n", "gqp", vim.diagnostic.goto_prev, "Prev Diagnostic")

--extras others
easymap({ "i", "n" }, "<C-s>", "<cmd>w<cr>", "Save")
easymap({ "i", "n" }, "<C-p>", vim.diagnostic.open_float, "Open Diagnostic Float")
easymap("n", ";", "A;", "Add ; to the end")
