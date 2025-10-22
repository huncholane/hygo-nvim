vim.cmd([[
function! NumberedTabPages()
  let s = ''
  for i in range(tabpagenr('$'))
    " Get the tab-local cwd for tab (i+1)
    let l:cwd = fnamemodify(getcwd(-1, i+1), ':t')

    " Highlight current tab
    if i + 1 == tabpagenr()
      let s .= '%#TabLineSel#'
    else
      let s .= '%#TabLine#'
    endif

    " Add clickable label: tab number + cwd
    let s .= '%' . (i+1) . 'T ' . (i+1) . ':' . l:cwd . ' '
  endfor
  let s .= '%#TabLineFill#%T'
  return s
endfunction

let g:qfjobs=[]
function! JobHandler(c, d, n) abort
  let lines = filter(copy(a:d), 'v:val !=# ""')
  if empty(lines)
    return
  endif

  " Step 1: save current qf
  let old = getqflist()

  " Step 2: parse new lines into qf entries using errorformat
  cgetexpr lines
  let new = getqflist()

  " Step 3: merge
  let merged = old + new

  " Step 4: set back
  call setqflist(merged, 'r')
endfunction
]])
