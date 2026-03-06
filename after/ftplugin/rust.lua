vim.cmd([[
comp rust_verbose
TSBufEnable highlight
]])
require("nvim-autopairs").remove_rule("`")
require("nvim-autopairs").remove_rule("'")

-- Fill the current match or struct
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.code_action({
    filter = function(action)
      return action.title:match("Fill")
    end,
    apply = true,
  })
end, { desc = "Fill" })

-- Remove all unused imports
vim.keymap.set("n", "<leader>i", function()
  -- initial cursor position
  local pos = vim.api.nvim_win_get_cursor(0)

  -- remove unused imports
  vim.lsp.buf.code_action({
    range = {
      ["start"] = { 1, 1 },
      ["end"] = { vim.api.nvim_buf_line_count(0), 1 },
    },
    filter = function(action)
      return action.title:match("Remove all unused imports")
    end,

    apply = true,
  })

  -- wait brief moment to restore cursor position
  vim.defer_fn(function()
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end, 50)
end)

--- Find the start index and end index for a pair of words.
--- Final position will be at the outermost w2.
--- @param w1 string Example <
--- @param w2 string Example >
local function find_outermost_pair(w1, w2)
  local s, e = 0, 0
  while true do
    vim.fn.searchpair(w1, "", w2, "b")
    local _s = vim.fn.col(".")
    vim.fn.searchpair(w1, "", w2, "")
    local _e = vim.fn.col(".")
    if _s == s then
      return s, e
    else
      s, e = _s, _e
    end
  end
end

-- Actions
vim.keymap.set("n", "<leader>a", "", { desc = "Actions" })

-- Toggle option
vim.keymap.set("n", "<leader>ao", function()
  -- Go to next or last option on current line
  local option = vim.fn.searchpos("Option", "", vim.fn.line("."))[2]
  if option == 0 then
    option = vim.fn.searchpos("Option", "bc", vim.fn.line("."))[2]
  end

  -- Move to the closest arrow
  local arrow = vim.fn.search("<", "", vim.fn.line("."))
  if arrow == 0 then
    arrow = vim.fn.search("<", "b", vim.fn.line("."))
  end

  -- Find starting position of current word
  local cw = vim.fn.expand("<cword>")
  vim.fn.search(cw, "bc", vim.fn.line("."))
  local cw_start = vim.fn.col(".")
  local cw_end = cw_start + #cw - 1

  -- Get start/end of arrows pair
  local s, e = find_outermost_pair("<", ">")
  if s == e then
    -- Handle no arrows (not possible for option to exist, just add option)
    local line = vim.api.nvim_get_current_line()
    line = line:sub(1, cw_end) .. ">" .. line:sub(cw_end + 1)
    line = line:sub(1, cw_start - 1) .. "Option<" .. line:sub(cw_start)
    vim.api.nvim_set_current_line(line)
  else
    -- Handle arrows
    if option > 0 then
      -- Option exists and so do arrows
      -- Delete outer arrows (right first to keep start index the same)
      local line = vim.api.nvim_get_current_line()
      line = line:sub(1, e - 1) .. line:sub(e + 1)
      line = line:sub(1, s - 1) .. line:sub(s + 1)
      line = line:sub(1, option - 1) .. line:sub(option + 6)
      vim.api.nvim_set_current_line(line)
      vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), option - 1 })
    else
      -- Option does not and exist but there are arrows
      -- Add outer left and right arrows (right first to keep start index the same)
      local line = vim.api.nvim_get_current_line()
      local wb = line:sub(1, s)
      local wb_pos = wb:find("%S+$")
      line = line:sub(1, e) .. ">" .. line:sub(e + 1)
      line = line:sub(1, wb_pos - 1) .. "Option<" .. line:sub(wb_pos)
      vim.api.nvim_set_current_line(line)
    end
  end
end, { desc = "Toggle Option" })
