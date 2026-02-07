local M = {}

local instances = {}
local next_instance_id = 1

local function create_instance()
  local id = next_instance_id
  next_instance_id = next_instance_id + 1
  
  instances[id] = {
    id = id,
    active = false,
    base_ref = nil,
    changed_files = {},
    current_index = 0,
    current_hunks = {},
    original_buf = nil,
    diff_buf = nil,
    sidebar_buf = nil,
    sidebar_win = nil,
    working_dir = vim.fn.getcwd(),
  }
  
  return instances[id]
end

local function get_instance_by_id(id)
  return instances[id]
end

local function get_instance_for_buffer(bufnr)
  local instance_id = vim.b[bufnr].onediff_instance_id
  return instance_id and instances[instance_id] or nil
end

local function get_current_instance()
  local current_buf = vim.api.nvim_get_current_buf()
  return get_instance_for_buffer(current_buf)
end

function M.start(target_file_path)
  local git_ops = require("my_extensions.onediff.git_ops")
  local settings = require("my_extensions.onediff.settings")
  
  local state = create_instance()

  state.original_buf = vim.api.nvim_get_current_buf()
  state.base_ref = settings.get("base_ref")
  state.changed_files = git_ops.list_changed_files(state.base_ref)
  state.current_index = 1
  
  if target_file_path then
    local git_root = git_ops.get_root()
    if git_root then
      local relative_path = target_file_path
      if target_file_path:find("^" .. vim.pesc(git_root)) then
        relative_path = target_file_path:sub(#git_root + 2)
      end
      
      for i, file in ipairs(state.changed_files) do
        if file.path == relative_path then
          state.current_index = i
          break
        end
      end
    end
  end
  
  state.active = true
  return state.id
end

function M.stop(instance_id)
  local state = instance_id and instances[instance_id] or get_current_instance()
  if not state then return end
  
  instances[state.id] = nil
end

function M.is_open()
  local state = get_current_instance()
  return state and state.active or false
end

function M.get_files()
  local state = get_current_instance()
  return state and state.changed_files or {}
end

function M.get_current_file()
  local state = get_current_instance()
  if not state or #state.changed_files == 0 then
    return nil
  end
  if state.current_index < 1 or state.current_index > #state.changed_files then
    return nil
  end
  return state.changed_files[state.current_index]
end

function M.get_current_index()
  local state = get_current_instance()
  return state and state.current_index or 0
end

function M.set_current_index(idx)
  local state = get_current_instance()
  if not state then return end
  
  if idx >= 1 and idx <= #state.changed_files then
    state.current_index = idx
  end
end

function M.get_file_count()
  local state = get_current_instance()
  return state and #state.changed_files or 0
end

function M.get_base_ref()
  local state = get_current_instance()
  return state and state.base_ref or nil
end

function M.set_base_ref(ref)
  local state = get_current_instance()
  if not state then return end
  state.base_ref = ref
end

function M.reload_files()
  local git_ops = require("my_extensions.onediff.git_ops")
  local state = get_current_instance()
  if not state then return end
  
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
  local state = get_current_instance()
  if not state then return end
  state.current_hunks = hunks
end

function M.get_hunks()
  local state = get_current_instance()
  return state and state.current_hunks or {}
end

function M.set_sidebar_buf(buf)
  local state = get_current_instance()
  if not state then return end
  
  state.sidebar_buf = buf
  
  if buf then
    vim.b[buf].onediff_instance_id = state.id
  end
end

function M.get_sidebar_buf()
  local state = get_current_instance()
  return state and state.sidebar_buf or nil
end

function M.set_sidebar_win(win)
  local state = get_current_instance()
  if not state then return end
  state.sidebar_win = win
end

function M.get_sidebar_win()
  local state = get_current_instance()
  return state and state.sidebar_win or nil
end

function M.set_diff_buf(buf)
  local state = get_current_instance()
  if not state then return end
  
  state.diff_buf = buf
  
  if buf then
    vim.b[buf].onediff_instance_id = state.id
  end
end

function M.get_diff_buf()
  local state = get_current_instance()
  return state and state.diff_buf or nil
end

function M.get_instance_for_buffer(bufnr)
  return get_instance_for_buffer(bufnr)
end

function M.focus_diff_window()
  local state = get_current_instance()
  if not state or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
    return false
  end
  
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == state.diff_buf then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end
  
  return false
end

function M.get_hunk_start_lines()
  local state = get_current_instance()
  if not state then return {} end
  
  local lines = {}
  for _, hunk in ipairs(state.current_hunks) do
    table.insert(lines, hunk.new_start)
  end
  table.sort(lines)
  return lines
end

return M
