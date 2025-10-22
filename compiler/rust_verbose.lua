vim.cmd([[
let current_compiler="rust_verbose"
set makeprg=RUST_BACKTRACE=1\ cargo

"   4: tests::utils::test_pairing
"             at ./tests/utils.rs:232:5
set efm=%I\ %#%n:\ %m,%Z\ %#at\ /%.%#
set efm+=%E\ %#%n:\ %m,%Z\ %#at\ \./%f:%l:%c

"thread 'time_period::y2023::m11nov_tests::test_2023_Nov_B767_MEM' panicked at tests/utils.rs:232:5:
set efm+=%Ethread\ '%m'\ panicked\ at\ %f:%l:%c:

"PDF@tests/samples/pdf/2023_Nov_B767_MEM.pdf
set efm+=%m@%f
]])
