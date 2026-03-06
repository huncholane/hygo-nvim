local M = {}

local terminal = require("claude.terminal")

local skip_flag = ""

function M.setup(opts)
  if opts.skip_permissions then
    skip_flag = " --dangerously-skip-permissions"
  end
end

function M.continue()
  terminal.toggle("claude --continue" .. skip_flag)
end

function M.new()
  terminal.kill()
  terminal.open("claude" .. skip_flag)
end

function M.resume()
  terminal.kill()
  terminal.open("claude --resume" .. skip_flag)
end

return M
