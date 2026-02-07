--- Find all gitsigns buffers in the current window.
local function find_gitsigns_bufs()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("^gitsigns:///.*") then
      table.insert(bufs, buf)
    end
  end
  return bufs
end

--- Toggle gitsigns diffthis from current status to last commit
local function toggle_diffthis()
  local _, gitsign_buf = next(find_gitsigns_bufs())
  if gitsign_buf == nil then
    vim.cmd(":Gitsigns diffthis")
  else
    vim.api.nvim_buf_delete(gitsign_buf, {})
  end
end

--- Set quickfix list with global hunks and go the next one.
local function next_global_hunk()
  vim.cmd("Gitsigns setqflist all")
  vim.defer_fn(function()
    local ok, _ = pcall(vim.cmd.cnext)
    if not ok then
      pcall(vim.cmd.cfirst)
    end
    pcall(vim.cmd.cclose)
  end, 50)
end

--- Set quickfix list with global hunks and go to the previous one.
local function prev_global_hunk()
  local ok, _ = vim.cmd("Gitsigns setqflist all")
  vim.defer_fn(function()
    if not ok then
      pcall(vim.cmd.clast)
    end
    pcall(vim.cmd.cclose)
  end, 50)
end

--- Clear gitsigns buffers when the current buffer has nothing to do with gitsigns.
--- Example: A gitdiff is open and I open a new file. I don't want to see the diff
--- on the old file anymore.
local function clear_unrelated_gitsigns_buffers()
  local _, gitsign_buf = next(find_gitsigns_bufs())

  -- Ignore if there is no gitsigns buffer
  if gitsign_buf == nil then
    return
  end

  -- Gather info on buffers
  local gitsign_name = vim.api.nvim_buf_get_name(gitsign_buf)
  local current_name = vim.api.nvim_buf_get_name(0)
  local diffed_name = gitsign_name:match(".*:(.*)$")

  -- Keep gitsigns buffer alive if current buffer is gitsigns, 
  -- current file, a terminal, or allowed filetype
  local allowed_filetypes = { TelescopePrompt = 1 }
  if
      current_name:find(diffed_name .. "$")
      or allowed_filetypes[vim.bo.filetype] == nil
      or vim.bo.terminal_job_id ~= nil
  then
    return
  end

  -- Close the gitsign buffer
  vim.api.nvim_buf_delete(gitsign_buf, {})
end

---@type LazySpec
return {
  "lewis6991/gitsigns.nvim",
  dependencies = { { "tpope/vim-fugitive" } },
  event = "VeryLazy",
  config = function()
    local gitsigns = require("gitsigns")
    gitsigns.setup()

    -- Leader maps
    vim.keymap.set("n", "<leader>gh", ":Gitsigns preview_hunk<cr>", { desc = "Preview Hunk" })
    vim.keymap.set("n", "<leader>gb", ":Telescope git_bcommits<cr>", { desc = "Buffer Commits" })
    vim.keymap.set("n", "<leader>gg", ":Git<cr>", { desc = "Fugitive" })
    vim.keymap.set("n", "<leader>gb", ":Gitsigns toggle_current_blame<cr>", { desc = "Toggle Blame" })
    vim.keymap.set("n", "<leader>gs", ":Telescope git_status<cr>", { desc = "Git Status" })
    vim.keymap.set("n", "<leader>gd", toggle_diffthis, { desc = "Toggle Diff" })

    -- Jump maps
    vim.keymap.set("n", "]h", ":Gitsigns next_hunk<cr>", { desc = "Next Hunk" })
    vim.keymap.set("n", "[h", ":Gitsigns prev_hunk<cr>", { desc = "Prev Hunk" })
    vim.keymap.set("n", "]H", next_global_hunk, { desc = "Global Hunk" })
    vim.keymap.set("n", "[H", prev_global_hunk, { desc = "Global Hunk" })

    -- Autocmds
    vim.api.nvim_create_autocmd("BufEnter", {
      callback = clear_unrelated_gitsigns_buffers,
    })
  end,
}
