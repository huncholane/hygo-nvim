---@type LazySpec
return {
  "junegunn/vim-easy-align",
  config = function()
    vim.g.easy_align_delimiters = {
      ["c"] = { pattern = [[\(#\|//\|--\)]], ignore_groups = {} },
    }
    vim.cmd([[
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
 ]])
  end,
}
