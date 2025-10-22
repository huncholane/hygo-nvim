vim.cmd([[
let current_compiler="pymod"
set makeprg=python\ -m
set efm=%f(%l\\,%c):\ %m
]])
