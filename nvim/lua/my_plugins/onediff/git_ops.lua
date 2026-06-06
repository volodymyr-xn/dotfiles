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

-- Accumulate per-path insertion/deletion counts from `git diff --numstat` output into `stats`.
-- Binary files (numstat "-\t-\t<path>") are recorded in the module-level binary_cache.
local function parse_numstat_into(output, stats)
  if not output then
    return
  end
  for line in output:gmatch("[^\n]+") do
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

-- Turn `git diff --name-status` output into file entries, skipping paths already in `seen`.
local function parse_status_into(output, files, stats, seen, root)
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
  parse_numstat_into(numstat_staged, stats)
  parse_numstat_into(numstat_unstaged, stats)

  local seen = {}
  parse_status_into(staged, files, stats, seen, root)
  parse_status_into(unstaged, files, stats, seen, root)

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

  local diff = run_argv({ "git", "diff", base_ref, "--", file_path })
  if diff and #vim.trim(diff) == 0 then
    diff = run_argv({ "git", "diff", "--cached", base_ref, "--", file_path })
  end
  return diff
end

local function spawn_diff(argv)
  local ok, job = pcall(vim.system, argv, { text = true })
  if not ok then return nil end
  return job
end

local function read_job(job)
  if not job then return "" end
  local ok, res = pcall(function() return job:wait() end)
  if not ok or not res or res.code ~= 0 then return "" end
  return res.stdout or ""
end

-- Spawn the two diff jobs without blocking; caller waits on both after doing other work.
function M.dispatch_diffs(file_path, base_ref)
  base_ref = base_ref or "HEAD"
  local file_job = spawn_diff({ "git", "diff", base_ref, "--", file_path })
  local staged_job = spawn_diff({ "git", "diff", "--cached", base_ref, "--", file_path })
  return file_job, staged_job
end

-- Wait on both diff jobs; if working-copy diff is empty, fall back to staged so fully-staged
-- files still render the staged changes as the main diff (matches get_file_diff semantics).
function M.wait_diffs(file_job, staged_job)
  local file_diff = read_job(file_job)
  local staged_diff = read_job(staged_job)
  if #vim.trim(file_diff) == 0 then
    file_diff = staged_diff
  end
  return file_diff, staged_diff
end

-- Async variant for background prefetch; callback is scheduled on the main loop.
function M.get_diffs_async(file_path, base_ref, callback)
  base_ref = base_ref or "HEAD"
  local file_diff, staged_diff
  local file_done, staged_done = false, false

  local function maybe_finish()
    if not (file_done and staged_done) then return end
    local main = file_diff or ""
    local staged = staged_diff or ""
    if #vim.trim(main) == 0 then
      main = staged
    end
    callback(main, staged)
  end

  vim.system({ "git", "diff", base_ref, "--", file_path }, { text = true }, vim.schedule_wrap(function(res)
    if res and res.code == 0 then file_diff = res.stdout end
    file_done = true
    maybe_finish()
  end))

  vim.system({ "git", "diff", "--cached", base_ref, "--", file_path }, { text = true }, vim.schedule_wrap(function(res)
    if res and res.code == 0 then staged_diff = res.stdout end
    staged_done = true
    maybe_finish()
  end))
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

-- Git's well-known empty-tree object; used as the "parent" of a root commit so its
-- diff shows every file as an addition instead of failing on a missing `<commit>^`.
local EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

-- Resolve a commit to { hash, short, parent, date, subject }. `parent` is the first-parent ref
-- (falling back to the empty tree for a root commit) so callers can diff parent..commit.
-- `date` is the author date in short YYYY-MM-DD form (%as).
function M.get_commit_info(commit)
  local out = run_argv({ "git", "show", "-s", "--format=%H%x1f%h%x1f%P%x1f%as%x1f%s", commit })
  if not out then
    return nil
  end
  local parts = vim.split(vim.trim(out), "\31", { plain = true })
  if #parts < 5 then
    return nil
  end
  local parent = parts[3]:match("^(%S+)") or EMPTY_TREE
  return { hash = parts[1], short = parts[2], parent = parent, date = parts[4], subject = parts[5] }
end

-- List files touched by a single commit (parent..commit). Renames are split into delete+add
-- via --no-renames so every reported path is valid for `git show commit:path`.
function M.list_commit_files(parent, commit)
  local files = {}
  local root = get_git_root()
  if not root then
    return files
  end

  binary_cache = {}
  local stats = {}
  parse_numstat_into(run_argv({ "git", "diff", "--no-renames", "--numstat", parent, commit }), stats)

  local seen = {}
  parse_status_into(run_argv({ "git", "diff", "--no-renames", "--name-status", parent, commit }), files, stats, seen, root)

  table.sort(files, function(a, b)
    return a.path < b.path
  end)

  return files
end

-- Unified diff for one file introduced by a commit (parent..commit side of the change).
function M.get_commit_file_diff(parent, commit, file_path)
  return run_argv({ "git", "diff", "--no-renames", parent, commit, "--", file_path })
end

-- The file's contents as they exist *at* the commit (the "after" side rendered in the buffer).
function M.get_commit_content(commit, file_path)
  return run_argv({ "git", "show", commit .. ":" .. file_path })
end

return M
