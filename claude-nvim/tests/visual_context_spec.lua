-- <leader>p (visual mode -> ui.prompt_visual_chat) must include
-- file path + line:col-line:col range alongside the selected text in the
-- context sent to claude.

local function reload()
  package.loaded["claude.ui"] = nil
  package.loaded["claude.runner"] = nil
  package.loaded["claude.store"] = nil
  return require("claude.ui"), require("claude.runner"), require("claude.store")
end

describe("visual selection context", function()
  local ui, runner
  local tmp_cwd, orig_cwd, tmp_data, orig_stdpath
  local orig_open_input

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_cwd = vim.fn.tempname()
    vim.fn.mkdir(tmp_cwd, "p")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_cwd))

    tmp_data = vim.fn.tempname()
    vim.fn.mkdir(tmp_data, "p")
    orig_stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(k) ---@diagnostic disable-line: duplicate-set-field
      if k == "data" then return tmp_data end
      return orig_stdpath(k)
    end

    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end

    ui, runner = reload()
    ui.setup({ width = 80, skip_permissions = false })
    runner.setup({ skip_permissions = false, debug = false })

    orig_open_input = ui.open_input
  end)

  after_each(function()
    ui.open_input = orig_open_input
    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end
    vim.fn.stdpath = orig_stdpath
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_cwd, "rf")
    vim.fn.delete(tmp_data, "rf")
  end)

  local function setup_buffer(rel_name, lines, ft)
    local fpath = tmp_cwd .. "/" .. rel_name
    vim.cmd("edit " .. vim.fn.fnameescape(fpath))
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = ft
    return buf
  end

  it("linewise selection: context has filename, line range, ft fence, and selected lines", function()
    setup_buffer("foo.lua", {
      "local M = {}",
      "function M.hello()",
      "  return 'hi'",
      "end",
      "return M",
    }, "lua")

    -- Visual line select lines 2..4
    vim.cmd("normal! 2GVjj\27")

    local captured
    ui.open_input = function(opts) captured = opts end ---@diagnostic disable-line: duplicate-set-field

    ui.prompt_visual_chat()

    assert.is_truthy(captured, "open_input should have been called")
    local ctx = captured.context or ""
    assert.matches("foo%.lua:2:1%-4:", ctx, "context should contain filename and line range")
    assert.matches("```lua", ctx, "should fence with filetype")
    assert.matches("function M%.hello%(%)", ctx, "selected text should appear")
    assert.matches("return 'hi'", ctx)
    assert.matches("end", ctx)
  end)

  it("charwise selection: column boundaries reflect actual selection", function()
    setup_buffer("bar.lua", {
      "abcdef",
      "ghijkl",
      "mnopqr",
    }, "lua")

    -- Char-visual from line 1 col 3 ('c') to line 2 col 4 ('j')
    vim.cmd("normal! gg")
    vim.cmd("normal! 0lvj0lll\27")
    -- Set marks explicitly to be deterministic
    vim.fn.setpos("'<", { 0, 1, 3, 0 })
    vim.fn.setpos("'>", { 0, 2, 4, 0 })

    -- Force visualmode to charwise so capture_visual_selection picks the
    -- column-aware path, not the linewise fallback.
    local orig_vm = vim.fn.visualmode
    vim.fn.visualmode = function() return "v" end ---@diagnostic disable-line: duplicate-set-field

    local captured
    ui.open_input = function(opts) captured = opts end ---@diagnostic disable-line: duplicate-set-field
    ui.prompt_visual_chat()
    vim.fn.visualmode = orig_vm

    assert.is_truthy(captured)
    local ctx = captured.context or ""
    assert.matches("bar%.lua:1:3%-2:4", ctx, "context should reflect 1:3-2:4 range")
    -- selection text spans "cdef" + newline + "ghij"
    assert.matches("cdef\nghij", ctx, "selected chars should appear in fence")
  end)

  it("buffer with no name falls back to [No Name]", function()
    -- Don't create a backing file: just a scratch buf.
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alpha", "beta", "gamma" })
    vim.bo[buf].filetype = "text"

    vim.cmd("normal! ggVj\27")

    local captured
    ui.open_input = function(opts) captured = opts end ---@diagnostic disable-line: duplicate-set-field
    ui.prompt_visual_chat()

    assert.is_truthy(captured)
    assert.matches("%[No Name%]:1:1%-2:", captured.context or "")
  end)

  it("send() concatenates context + user prompt and forwards to runner.send", function()
    setup_buffer("baz.lua", { "x = 1", "y = 2", "z = 3" }, "lua")
    vim.cmd("normal! ggVj\27")

    -- Use real open_input but stub runner.send so we can inspect final_text.
    local sent
    runner.send = function(_sid, text, _opts) ---@diagnostic disable-line: duplicate-set-field
      sent = text
      return true
    end

    ui.prompt_visual_chat()
    -- The floating prompt window is now open and is current. Type into it.
    vim.api.nvim_put({ "What does this do?" }, "c", true, true)
    -- Trigger <C-s> mapping to send.
    vim.cmd("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-s>", true, false, true), "x", false)

    assert.is_truthy(sent, "runner.send should have been invoked")
    assert.matches("baz%.lua:1:1%-2:", sent, "final text should contain file:line range")
    assert.matches("```lua", sent)
    assert.matches("x = 1", sent)
    assert.matches("y = 2", sent)
    assert.matches("What does this do%?", sent, "user-typed text should follow context")
  end)
end)
