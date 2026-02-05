local M = {}

local state = {
  active = false,
  base_ref = nil,
  changed_files = {},
  current_index = 0,
  current_hunks = {},
  original_buf = nil,
  diff_buf = nil,
  sidebar_buf = nil,
  sidebar_win = nil,
}

function M.start()
  local git_ops = require("my_extensions.onediff.git_ops")
  local settings = require("my_extensions.onediff.settings")

  state.original_buf = vim.api.nvim_get_current_buf()
  state.base_ref = settings.get("base_ref")
  state.changed_files = git_ops.list_changed_files(state.base_ref)
  state.current_index = 1
  state.active = true
end

function M.stop()
  state.active = false
  state.changed_files = {}
  state.current_index = 0
  state.current_hunks = {}
  state.diff_buf = nil
  state.sidebar_buf = nil
  state.sidebar_win = nil
end

function M.is_open()
  return state.active
end

function M.get_files()
  return state.changed_files
end

function M.get_current_file()
  if #state.changed_files == 0 then
    return nil
  end
  if state.current_index < 1 or state.current_index > #state.changed_files then
    return nil
  end
  return state.changed_files[state.current_index]
end

function M.get_current_index()
  return state.current_index
end

function M.set_current_index(idx)
  if idx >= 1 and idx <= #state.changed_files then
    state.current_index = idx
  end
end

function M.get_file_count()
  return #state.changed_files
end

function M.get_base_ref()
  return state.base_ref
end

function M.set_base_ref(ref)
  state.base_ref = ref
end

function M.reload_files()
  local git_ops = require("my_extensions.onediff.git_ops")
  local current_file = M.get_current_file()
  state.changed_files = git_ops.list_changed_files(state.base_ref)

  if current_file then
    for i, f in ipairs(state.changed_files) do
      if f.path == current_file.path then
        state.current_index = i
        return
      end
    end
  end
  state.current_index = math.min(state.current_index, #state.changed_files)
  if state.current_index < 1 and #state.changed_files > 0 then
    state.current_index = 1
  end
end

function M.set_hunks(hunks)
  state.current_hunks = hunks
end

function M.get_hunks()
  return state.current_hunks
end

function M.set_sidebar_buf(buf)
  state.sidebar_buf = buf
end

function M.get_sidebar_buf()
  return state.sidebar_buf
end

function M.set_sidebar_win(win)
  state.sidebar_win = win
end

function M.get_sidebar_win()
  return state.sidebar_win
end

function M.set_diff_buf(buf)
  state.diff_buf = buf
end

function M.get_diff_buf()
  return state.diff_buf
end

function M.get_hunk_start_lines()
  local lines = {}
  for _, hunk in ipairs(state.current_hunks) do
    table.insert(lines, hunk.new_start)
  end
  table.sort(lines)
  return lines
end

return M
