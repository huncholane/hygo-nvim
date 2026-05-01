local M = {}

local store = require("claude.store")

local function snippet(text, n)
  return (text or ""):gsub("%s+", " "):sub(1, n or 60)
end

function M.set_qf_from_prompt(p)
  local items = {}
  for _, f in ipairs(p.files or {}) do
    for _, h in ipairs(f.hunks or {}) do
      table.insert(items, {
        filename = f.path,
        lnum = h.start or 1,
        end_lnum = h.finish or h.start or 1,
        text = snippet(p.text, 80),
      })
    end
  end
  if #items == 0 then
    vim.notify("claude: prompt has no recorded changes", vim.log.levels.WARN)
    return
  end
  vim.fn.setqflist({}, " ", {
    title = "Claude: " .. snippet(p.text, 60),
    items = items,
  })
  vim.cmd("copen")
end

function M.qf_last()
  local prompts = store.all_prompts()
  if #prompts == 0 then
    vim.notify("claude: no prompts have caused changes yet", vim.log.levels.WARN)
    return
  end
  M.set_qf_from_prompt(prompts[1])
end

function M.prompts_picker()
  local ok_t, _ = pcall(require, "telescope")
  if not ok_t then
    vim.notify("claude: telescope.nvim not available", vim.log.levels.ERROR)
    return
  end
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local conf = require("telescope.config").values

  local prompts = store.all_prompts()
  if #prompts == 0 then
    vim.notify("claude: no prompts have caused changes yet", vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Claude prompts (" .. #prompts .. ")",
    finder = finders.new_table({
      results = prompts,
      entry_maker = function(p)
        local nfiles = #(p.files or {})
        local display = string.format(
          "%s  (%d file%s)  %s",
          os.date("%Y-%m-%d %H:%M", p.ts or 0),
          nfiles,
          nfiles == 1 and "" or "s",
          snippet(p.text, 70)
        )
        return {
          value = p,
          display = display,
          ordinal = (p.text or "") .. " " .. tostring(p.ts or ""),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local lines = {
          "# Prompt",
          "",
        }
        for _, l in ipairs(vim.split(entry.value.text or "", "\n", { plain = true })) do
          table.insert(lines, l)
        end
        table.insert(lines, "")
        for _, f in ipairs(entry.value.files or {}) do
          table.insert(lines, "diff --git a/" .. f.path .. " b/" .. f.path)
          for _, line in ipairs(vim.split(f.diff or "", "\n", { plain = true })) do
            table.insert(lines, line)
          end
          table.insert(lines, "")
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = "diff"
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          M.set_qf_from_prompt(entry.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
