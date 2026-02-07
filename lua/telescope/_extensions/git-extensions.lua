local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local utils = require("telescope.utils")

local conf = require("telescope.config").values
local git_command = utils.__git_command

local git = {}

git.status = function(opts)
  opts = opts or {}
  if not opts.cwd then
    local toplevel, ret = utils.get_os_command_output({ "git", "rev-parse", "--show-toplevel" })
    opts.cwd = toplevel[1]
  end
  if opts.is_bare then
    utils.notify("builtin.git_status", {
      msg = "This operation must be run in a work tree",
      level = "ERROR",
    })
    return
  end

  local args = { "status", "--porcelain=v1", "--", "." }

  local gen_new_finder = function()
    if vim.F.if_nil(opts.expand_dir, true) then
      table.insert(args, #args - 1, "-uall")
    end
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_status(opts))
    local output = utils.get_os_command_output(
      git_command({ "--no-pager", "diff", "--name-status", "HEAD~1", "HEAD", "--", "." }, opts),
      opts.cwd
    )

    return finders.new_table({
      results = output,
      entry_maker = function(line)
        local status, file = line:match("^(%a)%s+(.*)")
        if not status then
          return nil
        end
        return make_entry.gen_from_git_status(opts)(" " .. status .. " " .. file)
      end,
    })
  end

  local initial_finder = gen_new_finder()
  if not initial_finder then
    return
  end

  pickers
      .new(opts, {
        prompt_title = "Git Status",
        finder = initial_finder,
        previewer = previewers.new_buffer_previewer({
          title = "HEAD~1 HEAD Changes",
          define_preview = function(self, entry, status)
            local file = entry.value or entry.filename
            local output = vim.fn.systemlist({ "git", "diff", "HEAD~1", "HEAD", "--", file })
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, output)
          end,
        }),
        sorter = conf.file_sorter(opts),
        on_complete = {
          function(self)
            local prompt = action_state.get_current_line()

            -- HACK: self.manager:num_results() can return 0 despite having results
            -- due to some async/event loop shenanigans (#3316)
            local count = 0
            for _, entry in pairs(self.finder.results) do
              if entry and entry.valid ~= false then
                count = count + 1
              end
            end

            if count == 0 and prompt == "" then
              utils.notify("builtin.git_status", {
                msg = "No changes found",
                level = "INFO",
              })
            end
          end,
        },
        attach_mappings = function(prompt_bufnr, map)
          actions.git_staging_toggle:enhance({
            post = function()
              local picker = action_state.get_current_picker(prompt_bufnr)

              -- temporarily register a callback which keeps selection on refresh
              local selection = picker:get_selection_row()
              local callbacks = { unpack(picker._completion_callbacks) } -- shallow copy
              picker:register_completion_callback(function(self)
                self:set_selection(selection)
                self._completion_callbacks = callbacks
              end)

              -- refresh
              picker:refresh(gen_new_finder(), { reset_prompt = false })
            end,
          })

          map({ "i", "n" }, "<tab>", actions.git_staging_toggle)
          return true
        end,
      })
      :find()
end

return require("telescope").register_extension({
  exports = {
    previous_commit = git.status,
  },
})
