local M = {}

M.PICKERS = { "telescope", "fzf_lua", "fzf_vim", "mini_pick", "fff" }

local state_file = vim.fn.stdpath("data") .. "/ultraselect_picker"

local function read_state()
  local ok, lines = pcall(vim.fn.readfile, state_file)
  if ok and lines and lines[1] and lines[1] ~= "" then return lines[1] end
  return nil
end

local function write_state(name)
  vim.fn.writefile({ name }, state_file)
end

M.active = vim.g.active_picker or read_state() or "telescope"

local function load_picker(name)
  local ok, mod = pcall(require, "my_extensions.pickers." .. name)
  if not ok then
    vim.notify("ultraselect: failed to load picker '" .. name .. "': " .. tostring(mod), vim.log.levels.ERROR)
    return nil
  end
  return mod
end

function M.call(action, ...)
  local picker = load_picker(M.active)
  if not picker then return end

  local fn = picker[action]
  if type(fn) == "function" then
    fn(...)
  elseif fn == nil then
    vim.notify("ultraselect: picker '" .. M.active .. "' does not implement action '" .. action .. "'", vim.log.levels.WARN)
  end
end

function M.cycle()
  local current_idx = 1
  for i, name in ipairs(M.PICKERS) do
    if name == M.active then
      current_idx = i
      break
    end
  end

  local next_idx = (current_idx % #M.PICKERS) + 1
  M.set(M.PICKERS[next_idx])
end

function M.set(name)
  local valid = false
  for _, p in ipairs(M.PICKERS) do
    if p == name then valid = true; break end
  end

  if not valid then
    vim.notify("ultraselect: unknown picker '" .. name .. "'", vim.log.levels.WARN)
    return
  end

  M.active = name
  vim.g.active_picker = name
  write_state(name)
  vim.notify("Active picker: " .. name, vim.log.levels.INFO)
end

return M
