local M = {

  --- Gvdiff buffers mapped by origin buffer.
  diff_bufs = {},

  --- Filetypes to allow diff to stay open on BufEnter events.
  allowed_filetypes = {},

  --- Default settings
  --- @class git-extensions.settings
  defaults = {
    git_bcommit_diff_map = "<C-d>",
    leader = "<leader>g",
  },

  --- Final settings
  --- @type git-extensions.settings?
  settings = nil,

  open_previous_commits = ":Telescope git-extensions previous_commit<cr>",
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

--- Telescope git_bcommit with Gvdiff with settings.git_bcommit_diff_map
M.extended_bcommit_picker = function()
  require("telescope.builtin").git_bcommits({
    attach_mappings = function(_, map)
      local keymap = M.settings and M.settings.git_bcommit_diff_map or M.defaults.git_bcommit_diff_map
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      map("i", keymap, function(prompt_bufnr)
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd("Gvdiff " .. entry.value)
        local diff_buff = vim.api.nvim_get_current_buf()
        vim.cmd("wincmd l")
        M.diff_bufs[vim.api.nvim_get_current_buf()] = diff_buff
      end)

      return true
    end,
  })
end

--- Registers a key with the leader from settings.
M.register_keymap = function(key, command, desc)
  local leader = M.settings and M.settings.leader or M.defaults.leader
  vim.keymap.set("n", leader .. key, command, { desc = desc })
end

--- Sets up the extension. Make sure to set up `lewis6991/gitsigns.nvim`
--- and `tpope/vim-fugitive` first.
--- @param opts git-extensions.settings?
M.setup = function(opts)
  M.settings = opts
  -- Leader maps
  M.register_keymap("h", ":Gitsigns preview_hunk<cr>", "Preview Hunk")
  M.register_keymap("b", M.extended_bcommit_picker, "Buffer Commits")
  M.register_keymap("g", ":Git<cr>", "Fugitive")
  M.register_keymap("s", ":Telescope git_status<cr>", "Git Status")
  M.register_keymap("l", M.toggle_last_gvdiff, "Toggle Diff")
  M.register_keymap("p", M.open_previous_commits, "Previous Commit Files")

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
