---@type vim.lsp.Config
return {
	cmd = { "clangd" },
	filetypes = { "c" },
	root_markers = { "Makefile", "CMakeLists.txt" },
}
