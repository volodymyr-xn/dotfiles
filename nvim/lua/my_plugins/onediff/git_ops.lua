local M = {}

-- Cached repo root for the current session; cleared by M.invalidate_root().
local cached_root = nil
-- Memoized "is this path binary?" results from numstat (key: file_path).
local binary_cache = {}

-- Run an argv-form command via vim.system (no shell). Returns stdout string or nil on failure.
local function run_argv(argv, opts)
  local ok, res = pcall(function()
    return vim.system(argv, opts or { text = true }):wait()
  end)
  if not ok or not res or res.code ~= 0 then
    return nil
  end
  return res.stdout
end

local function get_git_root()
  if cached_root then
    return cached_root
  end

  local out = run_argv({ "git", "rev-parse", "--show-toplevel" })
  if out then
    cached_root = vim.trim(out)
    return cached_root
  end
  return nil
end

-- Drop the cached repo root, e.g. after cwd changes.
function M.invalidate_root()
  cached_root = nil
  binary_cache = {}
end

function M.list_changed_files(base_ref)
  local files = {}
  local root = get_git_root()
  if not root then
    return files
  end

  base_ref = base_ref or "HEAD"
  binary_cache = {}

  local staged = run_argv({ "git", "diff", "--cached", "--name-status", base_ref })
  local unstaged = run_argv({ "git", "diff", "--name-status", base_ref })

  local numstat_staged = run_argv({ "git", "diff", "--cached", "--numstat", base_ref })
  local numstat_unstaged = run_argv({ "git", "diff", "--numstat", base_ref })

  local stats = {}
  local function parse_numstat(output)
    if not output then
      return
    end
    for line in output:gmatch("[^\n]+") do
      -- numstat marks binary files as "-\t-\t<path>"; tonumber will return nil for "-".
      local adds, dels, path = line:match("^(%S+)%s+(%S+)%s+(.+)$")
      if path then
        if adds == "-" and dels == "-" then
          binary_cache[path] = true
        end

        local insertions = tonumber(adds) or 0
        local deletions = tonumber(dels) or 0
        if not stats[path] then
          stats[path] = { insertions = insertions, deletions = deletions }
        else
          stats[path].insertions = stats[path].insertions + insertions
          stats[path].deletions = stats[path].deletions + deletions
        end
      end
    end
  end

  parse_numstat(numstat_staged)
  parse_numstat(numstat_unstaged)

  local seen = {}
  local function parse_status(output)
    if not output then
      return
    end
    for line in output:gmatch("[^\n]+") do
      local status, path = line:match("^(%S+)%s+(.+)$")
      if status and path and not seen[path] then
        seen[path] = true
        local file_status = "modified"
        if status == "A" then
          file_status = "added"
        elseif status == "D" then
          file_status = "deleted"
        elseif status:match("^R") then
          file_status = "renamed"
        end
        local file_stats = stats[path] or { insertions = 0, deletions = 0 }
        table.insert(files, {
          path = path,
          full_path = root .. "/" .. path,
          status = file_status,
          insertions = file_stats.insertions,
          deletions = file_stats.deletions,
          is_binary = binary_cache[path] == true,
        })
      end
    end
  end

  parse_status(staged)
  parse_status(unstaged)

  local untracked = run_argv({ "git", "status", "--porcelain", "--untracked-files=all" })
  if untracked then
    for line in untracked:gmatch("[^\r\n]+") do
      local status_prefix = line:sub(1, 2)
      if status_prefix == "??" then
        local path = vim.trim(line:sub(4))

        if path and path ~= "" and not seen[path] then
          local full_path = root .. "/" .. path

          if vim.fn.isdirectory(full_path) ~= 1 then
            seen[path] = true
            local line_count = 0

            local file = io.open(full_path, "r")
            if file then
              for _ in file:lines() do
                line_count = line_count + 1
              end
              file:close()
            end

            table.insert(files, {
              path = path,
              full_path = full_path,
              status = "untracked",
              insertions = line_count,
              deletions = 0,
              is_binary = false,
            })
          end
        end
      end
    end
  end

  table.sort(files, function(a, b)
    return a.path < b.path
  end)

  return files
end

function M.get_file_diff(file_path, base_ref)
  base_ref = base_ref or "HEAD"

  local status_output = run_argv({ "git", "status", "--porcelain", "--untracked-files=all" })
  if status_output then
    for line in status_output:gmatch("[^\n]+") do
      local status_prefix = line:sub(1, 2)
      local path = line:sub(4)
      if status_prefix == "??" and path == file_path then
        return ""
      end
    end
  end

  local diff = run_argv({ "git", "diff", base_ref, "--", file_path })
  if diff and #vim.trim(diff) == 0 then
    diff = run_argv({ "git", "diff", "--cached", base_ref, "--", file_path })
  end
  return diff
end

function M.get_base_content(file_path, base_ref)
  base_ref = base_ref or "HEAD"
  return run_argv({ "git", "show", base_ref .. ":" .. file_path })
end

function M.get_current_content(file_path)
  local root = get_git_root()
  if not root then
    return nil
  end
  local full_path = root .. "/" .. file_path
  local file = io.open(full_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

-- Treat as binary if list_changed_files saw numstat "-\t-\t…"; fall back to a NUL-byte scan.
function M.is_binary_file(file_path, base_ref, full_path)
  if binary_cache[file_path] == true then
    return true
  end

  if full_path then
    local f = io.open(full_path, "rb")
    if f then
      local chunk = f:read(8192)
      f:close()
      if chunk and chunk:find("\0") then
        binary_cache[file_path] = true
        return true
      end
    end
  end

  return false
end

function M.get_staged_diff(file_path, base_ref)
  base_ref = base_ref or "HEAD"
  return run_argv({ "git", "diff", "--cached", base_ref, "--", file_path })
end

-- Write patch to a temp file and apply via git -C <root> apply --cached (no shell).
local function apply_patch(git_root, patch_text, reverse)
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(patch_text)
  f:close()

  local argv = { "git", "-C", git_root, "apply", "--cached" }
  if reverse then
    table.insert(argv, "--reverse")
  end
  table.insert(argv, tmp)

  run_argv(argv)
  os.remove(tmp)
  return true
end

function M.stage_hunk(git_root, patch_text)
  return apply_patch(git_root, patch_text, false)
end

function M.unstage_hunk(git_root, patch_text)
  return apply_patch(git_root, patch_text, true)
end

function M.is_git_repo()
  return get_git_root() ~= nil
end

function M.get_root()
  return get_git_root()
end

return M
