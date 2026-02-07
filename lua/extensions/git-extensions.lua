local M = {

  --- Gvdiff buffers mapped by origin buffer.
  diff_bufs = {},

  --- Filetypes to allow diff to stay open on BufEnter events.
  allowed_filetypes = {},
}
--- Finds the commit for last time the current file was changed.
M.current_file_last_change_commit_hash = function()
  local file = vim.fn.expand("%:p")
  local diff = vim.fn.system("git diff " .. file)
  local has_changed_from_current = vim.trim(diff) ~= ""
  local ref = vim.fn.system("git log -1 --format=%H -- " .. vim.fn.shellescape(file)):gsub("%s+", "")
  if not has_changed_from_current then
    ref = ref .. "~1"
  end
  return ref
end

--- Toggle gvdiff from current status to last time the file was changed.
--- Example: The file was last changed 5 commits ago.
M.toggle_last_gvdiff = function()
  local original_buffer = vim.api.nvim_get_current_buf()
  if M.diff_bufs[original_buffer] == nil then
    local rev = M.current_file_last_change_commit_hash()
    vim.cmd(":Gvdiff " .. rev)
    M.diff_bufs[original_buffer] = vim.api.nvim_get_current_buf()
    vim.print(original_buffer .. " " .. vim.api.nvim_get_current_buf())
    vim.cmd("wincmd l")
  else
    vim.api.nvim_buf_delete(M.diff_bufs[original_buffer], {})
    M.diff_bufs[original_buffer] = nil
  end
end

--- Set quickfix list with global hunks and go the next one.
M.next_global_hunk = function()
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
M.prev_global_hunk = function()
  local ok, _ = vim.cmd("Gitsigns setqflist all")
  vim.defer_fn(function()
    if not ok then
      pcall(vim.cmd.clast)
    end
    pcall(vim.cmd.cclose)
  end, 50)
end

--- Clear diff buffer when changing buffers.
--- Example: A gitdiff is open and I open a new file. I don't want to see the diff
--- on the old file anymore.
M.clear_current_tab_diff_buf = function()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_name = vim.api.nvim_buf_get_name(cur_buf)
  vim.print(cur_buf .. " " .. cur_name)
  if M.diff_bufs[cur_buf] ~= nil then
    return
  end
  for original_buf, diff_buf in pairs(M.diff_bufs) do
    vim.api.nvim_buf_delete(diff_buf, {})
    M.diff_bufs[original_buf] = nil
  end
end

--- Telescope files changed in the previous commit.
M.previous_commit_changed_files = function()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values

  local files = vim.fn.systemlist("git diff --name-only HEAD~1")

  pickers
      .new({}, {
        prompt_title = "Last Commit Changes",
        finder = finders.new_table({ results = files }),
        sorter = conf.file_sorter({}),
        previewer = previewers.new_termopen_previewer({
          get_command = function(entry)
            return { "git", "diff", "HEAD~1", "--", entry.value }
          end,
        }),
      })
      :find()
end

--- Sets up the extension. Make sure to set up `lewis6991/gitsigns.nvim`
--- and `tpope/vim-fugitive` first.
M.setup = function()
  -- Leader maps
  vim.keymap.set("n", "<leader>gh", ":Gitsigns preview_hunk<cr>", { desc = "Preview Hunk" })
  vim.keymap.set("n", "<leader>gb", ":Telescope git_bcommits<cr>", { desc = "Buffer Commits" })
  vim.keymap.set("n", "<leader>gg", ":Git<cr>", { desc = "Fugitive" })
  vim.keymap.set("n", "<leader>gs", ":Telescope git_status<cr>", { desc = "Git Status" })
  vim.keymap.set("n", "<leader>gl", M.toggle_last_gvdiff, { desc = "Toggle Diff" })
  vim.keymap.set("n", "<leader>gp", ":Telescope previous_commit<cr>", { desc = "Previous Commit Files" })

  -- Jump maps
  vim.keymap.set("n", "]h", ":Gitsigns next_hunk<cr>", { desc = "Next Hunk" })
  vim.keymap.set("n", "[h", ":Gitsigns prev_hunk<cr>", { desc = "Prev Hunk" })
  vim.keymap.set("n", "]H", M.next_global_hunk, { desc = "Global Hunk" })
  vim.keymap.set("n", "[H", M.prev_global_hunk, { desc = "Global Hunk" })

  -- Autocmds
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = M.clear_current_tab_diff_buf,
  })
end

return M
