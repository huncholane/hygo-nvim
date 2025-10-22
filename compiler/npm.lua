vim.cmd([[
let current_compiler="npm"
set makeprg=npm\ run
set efm=%f(%l\\,%c):\ %m
]])
