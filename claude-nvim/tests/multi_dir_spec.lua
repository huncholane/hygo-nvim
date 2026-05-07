-- Multi-tab + multi-directory behavior.
--
-- Rule: every resume entry point (resume_last, resume_session) must only
-- attach to the directory's saved session if there is no other open Claude
-- panel for that directory. Tabs in different directories must each be able
-- to resume their own session independently.

local function reload()
  package.loaded["claude.ui"] = nil
  package.loaded["claude.runner"] = nil
  package.loaded["claude.store"] = nil
  return require("claude.ui"), require("claude.runner"), require("claude.store")
end

local function mk_session(store, cwd, claude_id)
  local s = {
    id = store.uuid(),
    started_at = os.time(),
    cwd = cwd,
    claude_id = claude_id,
    prompts = {},
  }
  store.save(s)
  store.write_pointer({
    session_id = s.id,
    claude_id = claude_id,
    ts = os.time(),
    cwd = cwd,
  })
  return s
end

describe("multi-tab + multi-directory", function()
  local ui, runner, store
  local dir_a, dir_b
  local orig_cwd, tmp_data, orig_stdpath

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    dir_a = vim.fn.tempname()
    dir_b = vim.fn.tempname()
    vim.fn.mkdir(dir_a, "p")
    vim.fn.mkdir(dir_b, "p")

    tmp_data = vim.fn.tempname()
    vim.fn.mkdir(tmp_data, "p")
    orig_stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(k) ---@diagnostic disable-line: duplicate-set-field
      if k == "data" then return tmp_data end
      return orig_stdpath(k)
    end

    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end

    ui, runner, store = reload()
    ui.setup({ width = 80, skip_permissions = false })
    runner.setup({ skip_permissions = false, debug = false })
  end)

  after_each(function()
    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end
    vim.fn.stdpath = orig_stdpath
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(dir_a, "rf")
    vim.fn.delete(dir_b, "rf")
    vim.fn.delete(tmp_data, "rf")
  end)

  it("two tabs in different dirs each resume their own session", function()
    -- Pre-seed pointers + sessions in both dirs.
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess_a = mk_session(store, dir_a, "aaaaaaaa-1111-4222-8333-444444444444")
    vim.cmd("cd " .. vim.fn.fnameescape(dir_b))
    local sess_b = mk_session(store, dir_b, "bbbbbbbb-1111-4222-8333-444444444444")

    -- Tab 1: cd dir_a, resume_last
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    ui.resume_last()
    local sid_a = ui.current_sid()
    local got_a = runner.get_session(sid_a)
    assert.equals(sess_a.claude_id, got_a.claude_id, "tab1 resumes dir_a session")
    assert.equals(dir_a, got_a.cwd)

    -- Tab 2: new tab, cd dir_b, resume_last
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_b))
    assert.is_nil(ui.current_sid())
    ui.resume_last()
    local sid_b = ui.current_sid()
    local got_b = runner.get_session(sid_b)
    assert.equals(sess_b.claude_id, got_b.claude_id, "tab2 resumes dir_b session")
    assert.equals(dir_b, got_b.cwd)

    assert.are_not.equals(sid_a, sid_b)
  end)

  it("second tab in SAME dir starts new session even if pointer exists", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess_a = mk_session(store, dir_a, "cccccccc-1111-4222-8333-444444444444")

    ui.resume_last()
    local sid1 = ui.current_sid()
    assert.equals(sess_a.claude_id, runner.get_session(sid1).claude_id)

    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_a))
    ui.resume_last()
    local sid2 = ui.current_sid()
    assert.are_not.equals(sid1, sid2)
    assert.is_nil(runner.get_session(sid2).claude_id,
      "second tab in same dir must get fresh session, not pointer's claude_id")
  end)

  it("resume_session(claude_id) honors the same dir-conflict rule", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess_a = mk_session(store, dir_a, "dddddddd-1111-4222-8333-444444444444")

    -- Tab 1 in dir_a holds the dialog
    ui.resume_last()
    local sid1 = ui.current_sid()
    assert.equals(sess_a.claude_id, runner.get_session(sid1).claude_id)

    -- Tab 2 in dir_a tries explicit resume_session -> must start new
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_a))
    ui.resume_session(sess_a.claude_id)
    local sid2 = ui.current_sid()
    assert.are_not.equals(sid1, sid2)
    assert.is_nil(runner.get_session(sid2).claude_id,
      "resume_session in same dir as open panel must fall back to start_new")
  end)

  it("resume_session(claude_id) attaches when other tab is in a different dir", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    mk_session(store, dir_a, "eeeeeeee-1111-4222-8333-444444444444")
    ui.resume_last()
    local sid_a = ui.current_sid()

    -- dir_b has its own session
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_b))
    local sess_b = mk_session(store, dir_b, "ffffffff-1111-4222-8333-444444444444")
    ui.resume_session(sess_b.claude_id)
    local sid_b = ui.current_sid()

    assert.are_not.equals(sid_a, sid_b)
    assert.equals(sess_b.claude_id, runner.get_session(sid_b).claude_id,
      "different-dir tab should be able to resume_session normally")
    assert.equals(dir_b, runner.get_session(sid_b).cwd)
  end)

  it("after first tab closes, second tab in same dir CAN resume", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess_a = mk_session(store, dir_a, "99999999-1111-4222-8333-444444444444")
    ui.resume_last()
    local sid1 = ui.current_sid()

    -- close tab 1 (the dialog window) so panel.sid unbinds via TabClosed
    -- Simulate: open second tab, then drop the first by closing it.
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_a))
    -- close tab 1 (which is now tab 1, current is tab 2). go back & close.
    vim.cmd("tabprevious")
    local prev_tab = vim.api.nvim_get_current_tabpage()
    vim.cmd("tabclose")
    -- Trigger TabClosed cleanup explicitly (autocmd may run already).
    vim.api.nvim_exec_autocmds("TabClosed", { data = { tabpage = prev_tab } })

    -- Now only one tab remains, in dir_a; resume_last should attach to sess_a.
    -- (sid mirrors session.id, so reattaching the same session yields the
    -- same sid value — the point is that we attached, not that we made a
    -- new session.)
    ui.resume_last()
    local sid2 = ui.current_sid()
    local got = runner.get_session(sid2)
    assert.equals(sess_a.claude_id, got.claude_id,
      "no other open dialog -> resume should attach to dir's saved session")
    assert.equals(dir_a, got.cwd)
    assert.equals(sess_a.id, sid2,
      "reattached session should reuse its persisted session.id")
  end)
end)
