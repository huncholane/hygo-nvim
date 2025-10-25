vim.cmd [[
"Ignore the system path, add more system paths for python if needed
set efm=%-G%.%#miniconda%.%#

"Ignore the squiggly lines underneath error messages
set efm+=%-G%p%*[~^]

"Extract the error message
set efm+=%E%*[\ ]File\ \"%f\"%*[^l]line\ %l%.%#
set efm+=%C%p%m
set efm+=%Z%.%#

"Ignore any leftover blank lines
set efm+=%-G%p
]]
