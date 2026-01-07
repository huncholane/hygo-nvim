---@type LazySpec
return {
  "nvim-mini/mini.ai",
  event = "VeryLazy",
  config = function()
    require("mini.ai").setup({
      custom_textobjects = {
        -- Select between : and ,
        x = function(ai_type)
          local from = vim.fn.searchpos(":", "bnW")
          local to = vim.fn.searchpos(",", "nW")

          if from[1] == 0 or to[1] == 0 then
            return
          end

          if ai_type == "i" then
            -- inside: skip to next word after :
            vim.fn.cursor(from[1], from[2])
            vim.cmd("normal! w") -- move to next word
            local word_start = vim.fn.getcurpos()

            return {
              from = { line = word_start[2], col = word_start[3] },
              to = { line = to[1], col = to[2] - 1 },
            }
          else
            -- around: include : and ,
            return {
              from = { line = from[1], col = from[2] },
              to = { line = to[1], col = to[2] },
            }
          end
        end,
      },
    })
  end,
}
