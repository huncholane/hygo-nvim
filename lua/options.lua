local lsplist = {}
for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lsp")) do
  if file:sub(-4) == ".lua" then
    table.insert(lsplist, file:sub(1, -5))
  end
end
vim.lsp.enable(lsplist)

vim.cmd([[
set formatoptions-=cro
set errorformat^=%m@%f
set fdo=
set foldmethod=expr
set foldexpr=v:lua.vim.treesitter.foldexpr()
set noswapfile
colorscheme tokyonight-moon
set undofile
let mapleader=" "
set number
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set ignorecase
set smartcase
set foldlevel=99
set showtabline=2
set tabline=%!NumberedTabPages()
"set statusline=[%{getcwd()}]\ %f:%{nvim_treesitter#statusline(1000)}
]])
