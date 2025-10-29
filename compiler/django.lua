vim.cmd [[
set efm=

"Colored logging handler
"[1m[34m2025-10-29T12:25:27[0m [1m[32mINFO[0m [1m[36mapi/fedexcrew/authentication/serializers.py:55[0m [1m[36mroot[0m:[1m[35mserializers[0m [1m[37mLOG MESSAGE[0m
set efm+=%.%#3%.m%t%.%#36m%f:%l%.%#37m%m%.[0m

"Snag the django test error itself
set efm+=%EERROR:\ %o\ (%m)

"Ignore the system path, add more system paths for python if needed
set efm+=%-G%.%#miniconda%.%#

"Extract the error message
set efm+=%E%.%#File\ \"%f\"%*[^l]line\ %l%.%#
set efm+=%-Z%*[-]
set efm+=%+C%\\w%.%#
set efm+=%-C%.%#

"Ignore any leftover text without any error messages
set efm+=%-G%.%#
set efm+=%-G%.%.%#
set efm+=%-G%p
]]
