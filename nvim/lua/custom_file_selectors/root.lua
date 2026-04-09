local M = {}

-- Returns git root if inside a repo, otherwise falls back to cwd
function M.get()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]

  if git_root and git_root ~= "" and not git_root:match("^fatal") then
    return git_root
  end

  return vim.fn.getcwd()
end

return M
