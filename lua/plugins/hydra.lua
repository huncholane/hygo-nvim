---@type LazySpec
return {
  "nvimtools/hydra.nvim",
  event = "VeryLazy",
  config = function()
    local Hydra = require("hydra")

    Hydra({
      name = "Windows",
      mode = "n",
    body = "<leader>w",
      hint = [[
 _h_ _j_ _k_ _l_   move focus
 _H_ _J_ _K_ _L_   move window
 _+_ _-_ _>_ _<_   resize
 _=_               equalize
 _s_ _v_           split  h/v
 _o_               only
 _q_ _c_           close
 _<Esc>_             exit
]],
      config = {
        invoke_on_body = true,
        hint = { type = "window", border = "rounded", position = "bottom" },
      },
      heads = {
        { "h", "<Cmd>wincmd h<CR>" },
        { "j", "<Cmd>wincmd j<CR>" },
        { "k", "<Cmd>wincmd k<CR>" },
        { "l", "<Cmd>wincmd l<CR>" },
        { "H", "<Cmd>wincmd H<CR>" },
        { "J", "<Cmd>wincmd J<CR>" },
        { "K", "<Cmd>wincmd K<CR>" },
        { "L", "<Cmd>wincmd L<CR>" },
        { "+", "<Cmd>resize +2<CR>" },
        { "-", "<Cmd>resize -2<CR>" },
        { ">", "<Cmd>vertical resize +2<CR>" },
        { "<", "<Cmd>vertical resize -2<CR>" },
        { "=", "<Cmd>wincmd =<CR>" },
        { "s", "<Cmd>split<CR>" },
        { "v", "<Cmd>vsplit<CR>" },
        { "o", "<Cmd>only<CR>" },
        { "q", "<Cmd>close<CR>", { exit = true } },
        { "c", "<Cmd>close<CR>", { exit = true } },
        { "<Esc>", nil, { exit = true } },
      },
    })
  end,
}
