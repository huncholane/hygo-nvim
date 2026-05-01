local M = {}

local store = require("claude.store")

local function snippet(text, n)
  return (text or ""):gsub("%s+", " "):sub(1, n or 60)
end

function M.set_qf_from_prompt(p)
  local items = {}
  for _, f in ipairs(p.files or {}) do
    for _, h in ipairs(f.hunks or {}) do
      local added = h.added or 0
      local removed = h.removed or 0
      local stats
      if added == 0 and removed == 0 then
        stats = ""
      else
        stats = string.format("+%d -%d", added, removed)
      end
      table.insert(items, {
        filename = f.path,
        lnum = h.start or 1,
        end_lnum = h.finish or h.start or 1,
        text = stats,
      })
    end
  end
  if #items == 0 then
    vim.notify("claude: prompt has no recorded changes", vim.log.levels.WARN)
    return
  end
  local title = (p.text or ""):gsub("%s+", " ")
  table.insert(items, 1, { text = "▌ " .. title, valid = 0 })
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd("copen")
  pcall(function() require("extensions.qf-line-highlights").refresh_all() end)
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

local function projects_dir()
  local cwd = vim.fn.getcwd()
  local enc = cwd:gsub("[/%.]", "-")
  local home = vim.uv.os_homedir() or os.getenv("HOME") or ""
  return home .. "/.claude/projects/" .. enc
end

local function first_user_text(path, max_chars)
  local f = io.open(path, "r")
  if not f then return nil end
  local result
  for line in f:lines() do
    local ok, evt = pcall(vim.json.decode, line)
    if ok and type(evt) == "table" and evt.message and evt.message.role == "user" then
      local c = evt.message.content
      local text
      if type(c) == "string" then
        text = c
      elseif type(c) == "table" then
        local parts = {}
        for _, b in ipairs(c) do
          if type(b) == "table" and b.type == "text" and b.text then
            table.insert(parts, b.text)
          end
        end
        text = table.concat(parts, "\n")
      end
      if text and text ~= "" and not text:match("^<") then
        result = text:sub(1, max_chars or 4000)
        break
      end
    end
  end
  f:close()
  return result
end

local function list_sessions()
  local dir = projects_dir()
  local out = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return out end
  while true do
    local name, t = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if t == "file" and name:sub(-6) == ".jsonl" then
      local full = dir .. "/" .. name
      local stat = vim.uv.fs_stat(full)
      table.insert(out, {
        claude_id = name:sub(1, -7),
        path = full,
        mtime = stat and stat.mtime.sec or 0,
      })
    end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  return out
end

function M.sessions_picker()
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

  local sessions = list_sessions()
  if #sessions == 0 then
    vim.notify("claude: no sessions found for " .. vim.fn.getcwd(), vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = "Claude sessions (" .. #sessions .. ")",
    finder = finders.new_table({
      results = sessions,
      entry_maker = function(s)
        local first = first_user_text(s.path, 200) or "(no prompt)"
        local display = string.format(
          "%s  %s  %s",
          os.date("%Y-%m-%d %H:%M", s.mtime),
          s.claude_id:sub(1, 8),
          snippet(first, 80)
        )
        return {
          value = s,
          display = display,
          ordinal = display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        local text = first_user_text(entry.value.path, 4000) or "(no user message)"
        local lines = { "# " .. entry.value.claude_id, "" }
        for _, l in ipairs(vim.split(text, "\n", { plain = true })) do
          table.insert(lines, l)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        vim.bo[self.state.bufnr].filetype = "markdown"
      end,
    }),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value then
          require("claude.ui").resume_session(entry.value.claude_id)
        end
      end)
      return true
    end,
  }):find()
end

return M
