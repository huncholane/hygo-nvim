local lsplist = {}
for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lsp")) do
	if file:sub(-4) == ".lua" then
		table.insert(lsplist, file:sub(1, -5))
	end
end

vim.lsp.enable(lsplist)

local original_notify = vim.notify
vim.notify = function(msg, ...)
	if type(msg) == "string" and msg:match("Invalid server name") then
		return
	end
	return original_notify(msg, ...)
end

if vim.env.SSH_TTY ~= nil then
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = require("vim.ui.clipboard.osc52").copy("+"),
			["*"] = require("vim.ui.clipboard.osc52").copy("*"),
		},
		paste = {
			["+"] = require("vim.ui.clipboard.osc52").paste("+"),
			["*"] = require("vim.ui.clipboard.osc52").paste("*"),
		},
	}
end

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
highlight Normal guibg=NONE ctermbg=NONE
highlight EndOfBuffer guibg=NONE ctermbg=NONE
"set statusline=[%{getcwd()}]\ %f:%{nvim_treesitter#statusline(1000)}

" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
]])

local venv_path = vim.fn.getcwd() .. "/.venv"
if vim.fn.isdirectory(venv_path) == 1 then
	vim.env.VIRTUAL_ENV = venv_path
	vim.env.PATH = venv_path .. "/bin:" .. vim.env.PATH
end

vim.o.exrc = true
vim.g.maplocalleader = ","
vim.opt.scrolloff = 10
vim.diagnostic.config({
	virtual_text = {
		severity = vim.diagnostic.severity.ERROR,
	},
})
