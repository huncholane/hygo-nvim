local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local function open_with_system(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  if not entry then return end
  local path = entry.path or entry.filename or entry.value
  if not path then return end

  local cmd
  if vim.fn.has("mac") == 1 then
    cmd = { "open", path }
  elseif vim.fn.has("win32") == 1 then
    cmd = { "cmd.exe", "/C", "start", "", path }
  elseif vim.fn.executable("wslview") == 1 then
    cmd = { "wslview", path }
  else
    cmd = { "xdg-open", path }
  end
  vim.fn.jobstart(cmd, { detach = true })
end

local search = function(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "All Files",
    finder = finders.new_oneshot_job({
      "rg", "--files", "--hidden", "--no-ignore",
      "--glob", "!.git/*", "--glob", "!target/*",
    }, opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      map({ "i", "n" }, "<C-o>", function()
        open_with_system(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

return require("telescope").register_extension({
  exports = { all_files = search },
})
