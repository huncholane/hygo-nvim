local diagnostics_enabled = true
vim.api.nvim_create_user_command("ToggleDiagnostics", function(_)
  vim.diagnostic.enable(not diagnostics_enabled)
end, { desc = "Toggles Diagnostics" })

vim.api.nvim_create_user_command("ScratchFromCurrent", function()
  -- create new scratch buffer
  vim.cmd("enew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "hide"
  vim.bo.swapfile = false
  vim.bo.buflisted = false
  -- fill it with the contents of the previous buffer
  local prev = vim.fn.bufnr("#") -- previous buffer
  if prev ~= -1 then
    local lines = vim.api.nvim_buf_get_lines(prev, 0, -1, false)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
  vim.notify("📄 Copied current buffer into a scratch buffer")
end, { desc = "Copy current buffer contents into scratch" })

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = ".env*",
  callback = function(_)
    vim.bo.filetype = "env"
    vim.bo.syntax = "sh"
  end,
})

vim.api.nvim_create_user_command("Comp", function(args)
  vim.cmd("comp " .. args.args)
  vim.g.compiler = args.args
end, {
  nargs = 1,
  complete = "compiler",
  desc = "Wrapper around compiler to make current compiler available to UI",
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.tf",
  callback = function(_)
    vim.bo.filetype = "terraform"
  end,
})

local function get_make_completions()
  local handle = io.popen("grep -o -P '^\\w.*(?=:)' Makefile 2>/dev/null")
  if not handle then
    return {}
  end

  local result = {}
  for line in handle:lines() do
    table.insert(result, line)
  end
  handle:close()

  return result
end

vim.api.nvim_create_user_command("DJ", function(args)
  vim.cmd("Comp django")
  vim.cmd("set makeprg=make")
  vim.cmd("Make " .. args.args)
end, {
  nargs = "*",
  complete = get_make_completions,
  desc = "Run make commands with django compiler",
})

vim.api.nvim_create_user_command("Tab", function(args)
  vim.cmd("tabnew")
  vim.cmd("tcd " .. args.args)
end, {
  nargs = 1,
  complete = "dir",
})

vim.api.nvim_create_user_command("TabRename", function(opts)
  vim.t.tabname = opts.args
  vim.cmd.redrawtabline()
end, { nargs = 1, complete = "file", desc = "Rename current tab" })

vim.api.nvim_create_user_command("BufClean", function()
  -- Collect all visible buffers from every tab/window
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    visible[buf] = true
  end

  local deleted = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and not visible[buf] and vim.api.nvim_buf_get_option(buf, "buflisted") then
      vim.api.nvim_buf_delete(buf, { force = true })
      deleted = deleted + 1
    end
  end

  vim.notify("🧹 Deleted " .. deleted .. " hidden buffers (tabs kept intact)")
end, { desc = "Delete hidden buffers but keep tab buffers intact" })

------------------------------------------------------------
-- LastFile
------------------------------------------------------------

local last_buf = nil
vim.api.nvim_create_autocmd("BufLeave", {
  callback = function(args)
    local buf = vim.bo[args.buf]
    if buf.buflisted and vim.api.nvim_buf_is_valid(args.buf) and not buf.readonly then
      last_buf = args.buf
    end
  end,
})
vim.api.nvim_create_user_command("LastFile", function()
  if last_buf and vim.api.nvim_buf_is_valid(last_buf) then
    vim.api.nvim_set_current_buf(last_buf)
  else
    vim.notify("No last buffer recorded", vim.log.levels.WARN)
  end
end, {})

vim.cmd([[
command! -nargs=+ SetMakePrg execute 'set makeprg='.substitute(<q-args>, ' ', '\\ ', 'g')
command! ToggleClist if empty(filter(getwininfo(), 'v:val.quickfix')) | copen | else | cclose | endif
command! EditCurrentFiletype execute 'edit ~/.config/nvim/after/ftplugin/'.&filetype.'.lua'
command! Format lua require("conform").format()
command! TreeSitterFold setlocal foldexpr=v:lua.vim.treesitter.foldexpr() | setlocal foldmethod=expr
command! IndentFold setlocal foldmethod=indent
command! SyntaxFold setlocal foldmethod=syntax
command! -nargs=* Scratch enew | setlocal buftype=nofile bufhidden=hide noswapfile
command! -nargs=+ R enew | setlocal buftype=nofile bufhidden=hide noswapfile | silent read !<args>
command! -nargs=+ LinesOfCode execute '!find ./'.substitute(split(<q-args>)[0], ',', ' ./', '-g').' -name "*.'.substitute(split(<q-args>)[1], ',', '" -o -name "*.', 'g').'" | xargs wc -l'
command! SafeBD if winnr('$')==1 | echoerr 'Refuse to close last window' | else | silent! bd! | endif
command! -nargs=* TN tabe | tcd <args>
command! -nargs=+ Qfjob call add(g:qfjobs, [jobstart(<q-args>, {'on_stdout':'JobHandler', 'on_stderr':'JobHandler'}), <q-args>])
command! Killqfjobs for j in g:qfjobs | call jobstop(j[0]) | endfor | set g:qfjobs=[]
command! Restartqfjobs for j in g:qfjobs | call jobstop(j[0]) | let j[0] = jobstart(j[1]) | endfor
command! -nargs=1 Resize silent! exe 'resize '.(&lines*<args>/100)
command! -nargs=1 DotfilesTab tabnew | exe 'tcd ~/.dotfiles/'.<q-args>

autocmd InsertLeave,TextChanged,FocusLost * if &modifiable && !&readonly | silent! wall | endif
autocmd BufWritePre * silent! lua vim.lsp.buf.format()
]])
