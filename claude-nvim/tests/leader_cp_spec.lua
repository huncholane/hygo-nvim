-- <leader>cp = ui.open_prompt_keep_focus.
-- It should:
--   * resume the dir's saved session if a pointer exists AND no other tab
--     already has a panel open for the current cwd
--   * otherwise start a fresh session
--
-- Same rule applies to ui.prompt_visual_chat (which uses the same panel
-- bootstrap path).

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

describe("<leader>cp (open_prompt_keep_focus)", function()
  local ui, runner, store
  local dir_a, dir_b
  local orig_cwd, tmp_data, orig_stdpath
  local orig_open_input

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

    -- stub the floating input window so headless tests don't try to
    -- create real prompt UIs
    orig_open_input = ui.open_input
    ui.open_input = function() end ---@diagnostic disable-line: duplicate-set-field
  end)

  after_each(function()
    ui.open_input = orig_open_input
    while vim.fn.tabpagenr("$") > 1 do vim.cmd("tabclose") end
    vim.fn.stdpath = orig_stdpath
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(dir_a, "rf")
    vim.fn.delete(dir_b, "rf")
    vim.fn.delete(tmp_data, "rf")
  end)

  it("starts a new session when no pointer exists for the dir", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    ui.open_prompt_keep_focus()
    local sid = ui.current_sid()
    assert.is_truthy(sid)
    assert.is_nil(runner.get_session(sid).claude_id, "fresh session shouldn't have a claude_id")
  end)

  it("resumes the dir's saved session when no other tab has it open", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess = mk_session(store, dir_a, "aaaaaaaa-cccc-4ddd-9eee-fffffffffff1")

    ui.open_prompt_keep_focus()
    local sid = ui.current_sid()
    local got = runner.get_session(sid)
    assert.equals(sess.claude_id, got.claude_id, "leader cp should resume pointer when no conflict")
    assert.equals(dir_a, got.cwd)
  end)

  it("starts NEW session when another tab already has dir's panel open", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess = mk_session(store, dir_a, "bbbbbbbb-cccc-4ddd-9eee-fffffffffff2")

    -- tab1: open via leader cp -> resumes
    ui.open_prompt_keep_focus()
    local sid1 = ui.current_sid()
    assert.equals(sess.claude_id, runner.get_session(sid1).claude_id)

    -- tab2 in same dir: leader cp must start new
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_a))
    ui.open_prompt_keep_focus()
    local sid2 = ui.current_sid()

    assert.are_not.equals(sid1, sid2, "tab2 must not reuse tab1's sid")
    assert.is_nil(runner.get_session(sid2).claude_id,
      "tab2 leader cp should fall back to fresh session")
  end)

  it("two tabs, different dirs: each leader cp resumes its own dir", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    local sess_a = mk_session(store, dir_a, "11111111-cccc-4ddd-9eee-fffffffffff3")
    vim.cmd("cd " .. vim.fn.fnameescape(dir_b))
    local sess_b = mk_session(store, dir_b, "22222222-cccc-4ddd-9eee-fffffffffff4")

    -- tab1 in dir_a
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    ui.open_prompt_keep_focus()
    local sid_a = ui.current_sid()
    assert.equals(sess_a.claude_id, runner.get_session(sid_a).claude_id)

    -- tab2 in dir_b via :tcd
    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(dir_b))
    ui.open_prompt_keep_focus()
    local sid_b = ui.current_sid()

    assert.are_not.equals(sid_a, sid_b)
    assert.equals(sess_b.claude_id, runner.get_session(sid_b).claude_id,
      "different-dir tab should resume its own pointer")
    assert.equals(dir_b, runner.get_session(sid_b).cwd)
  end)

  it("subsequent leader cp in same tab is a no-op (keeps existing sid)", function()
    vim.cmd("cd " .. vim.fn.fnameescape(dir_a))
    ui.open_prompt_keep_focus()
    local sid1 = ui.current_sid()
    ui.open_prompt_keep_focus()
    local sid2 = ui.current_sid()
    assert.equals(sid1, sid2, "same tab should not spawn a new sid each time")
  end)
end)
