-- Verifies: when tab1 holds an active session and tab2 calls resume_last,
-- tab2 must NOT attach to tab1's session — it must start a fresh one.

local function reload()
  package.loaded["claude.ui"] = nil
  package.loaded["claude.runner"] = nil
  package.loaded["claude.store"] = nil
  return require("claude.ui"), require("claude.runner"), require("claude.store")
end

describe("multi-tab session isolation", function()
  local ui, runner, store
  local tmp_cwd
  local orig_cwd
  local orig_data
  local tmp_data

  before_each(function()
    orig_cwd = vim.fn.getcwd()
    tmp_cwd = vim.fn.tempname()
    vim.fn.mkdir(tmp_cwd, "p")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp_cwd))

    -- redirect stdpath("data") so store writes to tmp
    tmp_data = vim.fn.tempname()
    vim.fn.mkdir(tmp_data, "p")
    orig_data = vim.fn.stdpath
    vim.fn.stdpath = function(k) ---@diagnostic disable-line: duplicate-set-field
      if k == "data" then return tmp_data end
      return orig_data(k)
    end

    -- close any extra tabs from prior test
    while vim.fn.tabpagenr("$") > 1 do
      vim.cmd("tabclose")
    end

    ui, runner, store = reload()
    ui.setup({ width = 80, skip_permissions = false })
    runner.setup({ skip_permissions = false, debug = false })
  end)

  after_each(function()
    while vim.fn.tabpagenr("$") > 1 do
      vim.cmd("tabclose")
    end
    vim.fn.stdpath = orig_data
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
    vim.fn.delete(tmp_cwd, "rf")
    vim.fn.delete(tmp_data, "rf")
  end)

  it("resume_last in second tab spawns new session, not the one bound to first tab", function()
    -- Tab 1: simulate an existing attached session with a known claude_id.
    local fake_claude_id = "11111111-aaaa-4bbb-bccc-222222222222"
    local sess1 = {
      id = store.uuid(),
      started_at = os.time(),
      cwd = tmp_cwd,
      claude_id = fake_claude_id,
      prompts = {},
    }
    store.save(sess1)
    store.write_pointer({
      session_id = sess1.id,
      claude_id = fake_claude_id,
      ts = os.time(),
      cwd = tmp_cwd,
    })

    -- Bind sess1 to tab1's panel (no real claude job — attach_existing only registers state).
    local sid1 = runner.attach_existing(sess1)
    -- Force panel.sid for current tab via start_new path — but we want sid1 specifically:
    -- call resume_last from tab1 which will pick up the pointer and attach sess1.
    ui.resume_last()

    local tab1_sid = ui.current_sid()
    assert.is_truthy(tab1_sid, "tab1 should have a sid after resume_last")
    local tab1_sess = runner.get_session(tab1_sid)
    assert.equals(fake_claude_id, tab1_sess.claude_id)

    -- Tab 2: new tab in same cwd, call resume_last.
    vim.cmd("tabnew")
    -- Sanity: new tab, no panel yet.
    assert.is_nil(ui.current_sid())

    ui.resume_last()
    local tab2_sid = ui.current_sid()

    assert.is_truthy(tab2_sid, "tab2 should have a sid after resume_last")
    assert.are_not.equals(tab1_sid, tab2_sid, "tab2 must not reuse tab1's sid")

    local tab2_sess = runner.get_session(tab2_sid)
    assert.is_truthy(tab2_sess)
    -- New session: distinct internal id, no inherited claude_id (start_new => nil)
    assert.are_not.equals(sess1.id, tab2_sess.id, "tab2 must have distinct session.id")
    assert.is_nil(tab2_sess.claude_id, "tab2 fresh session should not inherit claude_id")
  end)

  it("resume_last in only tab still attaches when no conflict", function()
    local fake_claude_id = "33333333-cccc-4ddd-eeee-444444444444"
    local sess = {
      id = store.uuid(),
      started_at = os.time(),
      cwd = tmp_cwd,
      claude_id = fake_claude_id,
      prompts = {},
    }
    store.save(sess)
    store.write_pointer({
      session_id = sess.id,
      claude_id = fake_claude_id,
      ts = os.time(),
      cwd = tmp_cwd,
    })

    ui.resume_last()
    local sid = ui.current_sid()
    assert.is_truthy(sid)
    local got = runner.get_session(sid)
    assert.equals(fake_claude_id, got.claude_id, "single tab should resume pointer's claude_id")
  end)
end)
