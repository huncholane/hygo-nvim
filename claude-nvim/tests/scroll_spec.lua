-- Scroll + spinner behavior in the panel buffer.
--
-- Requirements covered:
-- 1. User can scroll up while streaming happens (no force-snap to bottom).
-- 2. Spinner appears at bottom immediately after a prompt is submitted.
-- 3. Spinner keeps spinning across streaming chunks.
-- 4. Panel keeps autoscrolling to bottom until the user interacts with it
--    (interaction = scroll away from bottom).

local function reload()
  package.loaded["claude.ui"] = nil
  package.loaded["claude.runner"] = nil
  package.loaded["claude.store"] = nil
  return require("claude.ui"), require("claude.runner"), require("claude.store")
end

local function last_line(buf)
  local lc = vim.api.nvim_buf_line_count(buf)
  return vim.api.nvim_buf_get_lines(buf, lc - 1, lc, false)[1] or ""
end

describe("panel scroll + spinner", function()
  local ui, runner
  local tmp_cwd, orig_cwd, tmp_data, orig_stdpath

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
  end)

  after_each(function()
    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end
    vim.fn.stdpath = orig_stdpath
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_cwd, "rf")
    vim.fn.delete(tmp_data, "rf")
  end)

  it("spinner appears at bottom immediately after prompt submit", function()
    ui.start_new()
    local p = ui._test_get_panel()
    ui.append_user_prompt(p.sid, "hello")

    assert.is_true(p.spinner.active, "spinner should be active right after prompt submit")
    assert.matches("thinking", last_line(p.buf), "last buffer line should show spinner text")
    assert.is_truthy(p.spinner.row, "spinner row should be tracked")
  end)

  it("spinner keeps spinning across streaming chunks", function()
    ui.start_new()
    local p = ui._test_get_panel()
    ui.append_user_prompt(p.sid, "hi")

    ui.append_assistant_text(p.sid, "first chunk ")
    vim.wait(40)
    ui.append_assistant_text(p.sid, "second chunk\n")
    vim.wait(40)
    ui.append_assistant_text(p.sid, "third\n")
    vim.wait(40)

    assert.is_true(p.spinner.active, "spinner should still be active during streaming")
    assert.matches("thinking", last_line(p.buf), "spinner row should still be at bottom")
  end)

  it("autoscrolls to bottom while user has not interacted", function()
    ui.start_new()
    local p = ui._test_get_panel()
    assert.is_true(p.autoscroll, "default autoscroll true")

    ui.append_user_prompt(p.sid, "hi")
    for i = 1, 30 do
      ui.append_assistant_text(p.sid, "stream line " .. i .. "\n")
    end
    vim.wait(80)

    local lc = vim.api.nvim_buf_line_count(p.buf)
    local cur = vim.api.nvim_win_get_cursor(p.win)
    assert.equals(lc, cur[1], "cursor should be parked on last line while autoscrolling")
    assert.is_true(p.autoscroll, "autoscroll should remain enabled")
  end)

  it("does NOT force-scroll when user has scrolled away from bottom", function()
    ui.start_new()
    local p = ui._test_get_panel()
    ui.append_user_prompt(p.sid, "hi")
    for i = 1, 30 do
      ui.append_assistant_text(p.sid, "L" .. i .. "\n")
    end
    vim.wait(80)

    -- Simulate user scrolling up: park cursor mid-buffer and disable autoscroll
    -- (mimicking what the WinScrolled autocmd would do once botline < lc).
    vim.api.nvim_win_set_cursor(p.win, { 5, 0 })
    ui._test_set_autoscroll(p, false)

    -- Stream more content while user is "reading" upper part of buffer.
    for i = 1, 10 do
      ui.append_assistant_text(p.sid, "MORE" .. i .. "\n")
    end
    vim.wait(80)

    local cur = vim.api.nvim_win_get_cursor(p.win)
    assert.equals(5, cur[1], "cursor must stay where user parked it; no force scroll")
    assert.is_false(p.autoscroll, "autoscroll stays disabled until next user prompt")
  end)

  it("new user prompt re-enables autoscroll and snaps to bottom", function()
    ui.start_new()
    local p = ui._test_get_panel()
    ui.append_user_prompt(p.sid, "first")
    for i = 1, 20 do ui.append_assistant_text(p.sid, "x" .. i .. "\n") end
    vim.wait(60)

    -- user scrolled away
    vim.api.nvim_win_set_cursor(p.win, { 3, 0 })
    ui._test_set_autoscroll(p, false)

    -- second prompt: should reset autoscroll and snap cursor to bottom
    ui.append_user_prompt(p.sid, "second")
    vim.wait(40)

    assert.is_true(p.autoscroll, "new prompt should re-enable autoscroll")
    local lc = vim.api.nvim_buf_line_count(p.buf)
    local cur = vim.api.nvim_win_get_cursor(p.win)
    assert.equals(lc, cur[1], "cursor should be at last line after new prompt")
  end)
end)
