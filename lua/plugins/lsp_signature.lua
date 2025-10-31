---@type LazySpec
return {
  "ray-x/lsp_signature.nvim",
  enabled = false,
  opts = {
    hint_enable = false,
    handler_opts = {
      border = "single",
    },
    toggle_key = "<C-k>",
    floating_window_above_cur_line = false,
    floating_window_off_x = 1000,
    floating_window_off_y = -1000,
  },
}
