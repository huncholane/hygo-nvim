local M = {}

local function data_dir()
  local d = vim.fn.stdpath("data") .. "/claude-nvim"
  vim.fn.mkdir(d, "p")
  return d
end

local function cwd_dir()
  local cwd = vim.fn.getcwd()
  local enc = cwd:gsub("/", "%%")
  local d = data_dir() .. "/" .. enc
  vim.fn.mkdir(d, "p")
  return d
end

function M.session_path(id)
  return cwd_dir() .. "/session-" .. id .. ".json"
end

local function pointer_path()
  return cwd_dir() .. "/last.json"
end

function M.write_pointer(info)
  local f = io.open(pointer_path(), "w")
  if not f then return false end
  f:write(vim.json.encode(info))
  f:close()
  return true
end

function M.read_pointer()
  local f = io.open(pointer_path(), "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok then return nil end
  return data
end

function M.list_sessions()
  local d = cwd_dir()
  local files = vim.fn.glob(d .. "/session-*.json", false, true)
  local out = {}
  for _, f in ipairs(files) do
    local stat = vim.uv.fs_stat(f)
    if stat then
      table.insert(out, { path = f, mtime = stat.mtime.sec })
    end
  end
  table.sort(out, function(a, b) return a.mtime > b.mtime end)
  return out
end

function M.load_path(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if not ok then return nil end
  return data
end

function M.load(id)
  return M.load_path(M.session_path(id))
end

function M.save(session)
  local f = io.open(M.session_path(session.id), "w")
  if not f then return false end
  f:write(vim.json.encode(session))
  f:close()
  return true
end

function M.all_prompts()
  local out = {}
  for _, entry in ipairs(M.list_sessions()) do
    local s = M.load_path(entry.path)
    if s and s.prompts then
      for _, p in ipairs(s.prompts) do
        local copy = vim.deepcopy(p)
        copy.session_id = s.id
        copy.claude_id = s.claude_id
        table.insert(out, copy)
      end
    end
  end
  table.sort(out, function(a, b) return (a.ts or 0) > (b.ts or 0) end)
  return out
end

function M.uuid()
  math.randomseed((os.time() * 1000 + (vim.uv.hrtime() % 1e6)) % 2147483647)
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return (template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%x", v)
  end))
end

return M
