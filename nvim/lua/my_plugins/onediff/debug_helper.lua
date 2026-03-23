local M = {}

function M.test_list_files()
  local git_ops = require("my_plugins.onediff.git_ops")
  local files = git_ops.list_changed_files("HEAD")
  
  print("=== OneDiff Debug: list_changed_files() ===")
  print(string.format("Total files: %d", #files))
  print("\nFiles list:")
  for i, file in ipairs(files) do
    print(string.format("  %d. [%s] %s (+%d -%d)", 
      i, file.status, file.path, file.insertions or 0, file.deletions or 0))
  end
  print("\nUntracked files only:")
  local untracked_count = 0
  for i, file in ipairs(files) do
    if file.status == "untracked" then
      untracked_count = untracked_count + 1
      print(string.format("  %d. %s (+%d lines)", 
        untracked_count, file.path, file.insertions or 0))
    end
  end
  if untracked_count == 0 then
    print("  (none)")
  end
  print("=========================================")
end

function M.test_git_status()
  print("=== OneDiff Debug: Raw git status ===")
  local handle = io.popen("git status --porcelain --untracked-files=all 2>&1")
  if handle then
    local result = handle:read("*a")
    handle:close()
    print(result)
  else
    print("ERROR: Could not run git status")
  end
  print("=====================================")
end

vim.api.nvim_create_user_command("OneDiffDebug", function()
  M.test_git_status()
  print("")
  M.test_list_files()
end, { desc = "Debug OneDiff file detection" })

return M
