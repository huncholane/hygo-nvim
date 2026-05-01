local M = {}

local skip_permissions = false

function M.setup(opts)
  if opts and opts.skip_permissions then skip_permissions = true end
end

local function strip_fences(text)
  local lines = vim.split(text or "", "\n", { plain = true })
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if #lines >= 2 and lines[1]:match("^```") then
    table.remove(lines, 1)
    if lines[#lines] and lines[#lines]:match("^```%s*$") then
      table.remove(lines)
    end
  end
  return table.concat(lines, "\n")
end

function M.commit()
  vim.system({ "git", "diff", "--staged" }, { text = true }, vim.schedule_wrap(function(diff_out)
    if diff_out.code ~= 0 then
      vim.notify("git diff failed: " .. (diff_out.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local diff = diff_out.stdout or ""
    if diff:match("^%s*$") then
      vim.notify("claude: no staged changes", vim.log.levels.WARN)
      return
    end
    vim.notify("claude: writing commit message…")
    local prompt = "Write a Conventional Commits style commit message for the following staged git diff. "
      .. "Subject line under 72 chars, imperative mood. Optional body explains why if non-obvious. "
      .. "Output ONLY the commit message. No explanation, no markdown fences.\n\n"
      .. diff
    local cmd = { "claude", "-p", prompt }
    if skip_permissions then table.insert(cmd, "--dangerously-skip-permissions") end
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(out)
      if out.code ~= 0 then
        vim.notify("claude failed: " .. (out.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local msg = strip_fences(out.stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if msg == "" then
        vim.notify("claude: empty commit message", vim.log.levels.ERROR)
        return
      end
      vim.system(
        { "git", "commit", "-F", "-" },
        { text = true, stdin = msg },
        vim.schedule_wrap(function(commit_out)
          if commit_out.code ~= 0 then
            vim.notify(
              "git commit failed: " .. (commit_out.stderr ~= "" and commit_out.stderr or commit_out.stdout or ""),
              vim.log.levels.ERROR
            )
            return
          end
          local subject = msg:match("^[^\n]*") or msg
          vim.notify("commit: " .. subject)
        end)
      )
    end))
  end))
end

return M
