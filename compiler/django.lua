vim.cmd [[
set efm=
"Ignore the system path, add more system paths for python if needed
"set efm+=%-G%.%#miniconda%.%#

"Extract the error message
set efm+=%E%.%#File\ \"%f\"%*[^l]line\ %l%.%#
set efm+=%-Z%*[-]
set efm+=%C%.%#Errno\ %n]\ %m
set efm+=%-C%.%#

"Ignore any leftover text without any error messages
set efm+=%-G%.%#
]]
