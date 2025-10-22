local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This plugin requires nvim-telescope/telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local devicons = require("nvim-web-devicons")

local M = {}

M.current_folder = function(opts)
  opts = opts or {}
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    print("No file open")
    return
  end

  local cwd = vim.fn.fnamemodify(current_file, ":h")
  local files = vim.fn.readdir(cwd, function(name)
    return name ~= "." and name ~= ".."
  end)

  -- turn into entries with icons
  local entries = {}
  for _, fname in ipairs(files) do
    local icon, hl = devicons.get_icon(fname, vim.fn.fnamemodify(fname, ":e"), { default = true })
    table.insert(entries, {
      value = fname,
      display = icon .. " " .. fname,
      ordinal = fname,
      hl_group = hl,
    })
  end

  pickers.new(opts, {
    prompt_title = "Files in " .. cwd,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry) return entry end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local filename = cwd .. "/" .. selection.value
        vim.cmd("edit " .. vim.fn.fnameescape(filename))
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    current_folder = M.current_folder,
  },
})
