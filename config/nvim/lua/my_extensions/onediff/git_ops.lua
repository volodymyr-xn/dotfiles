local M = {}

local function run_cmd(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result
end

local function get_git_root()
  local result = run_cmd("git rev-parse --show-toplevel")
  if result then
    return vim.trim(result)
  end
  return nil
end

function M.list_changed_files(base_ref)
  local files = {}
  local root = get_git_root()
  if not root then
    return files
  end

  base_ref = base_ref or "HEAD"
  local staged = run_cmd(string.format("git diff --cached --name-status %s", base_ref))
  local unstaged = run_cmd(string.format("git diff --name-status %s", base_ref))

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
        table.insert(files, {
          path = path,
          full_path = root .. "/" .. path,
          status = file_status,
        })
      end
    end
  end

  parse_status(staged)
  parse_status(unstaged)

  table.sort(files, function(a, b)
    return a.path < b.path
  end)

  return files
end

function M.get_file_diff(file_path, base_ref)
  base_ref = base_ref or "HEAD"
  local diff = run_cmd(string.format("git diff %s -- '%s'", base_ref, file_path))
  if diff and #vim.trim(diff) == 0 then
    diff = run_cmd(string.format("git diff --cached %s -- '%s'", base_ref, file_path))
  end
  return diff
end

function M.get_base_content(file_path, base_ref)
  base_ref = base_ref or "HEAD"
  local content = run_cmd(string.format("git show %s:'%s'", base_ref, file_path))
  return content
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

function M.is_git_repo()
  return get_git_root() ~= nil
end

function M.get_root()
  return get_git_root()
end

return M
