local M = {}

local config = {
  pickers = { "telescope", "fzf_lua", "fzf_vim", "fff" },
  state_file = vim.fn.stdpath("data") .. "/ultraselect_picker",
  default_picker = "telescope",
}

local function read_state()
  local ok, lines = pcall(vim.fn.readfile, config.state_file)
  if ok and lines and lines[1] and lines[1] ~= "" then return lines[1] end
  return nil
end

local function write_state(name)
  vim.fn.writefile({ name }, config.state_file)
end

-- Public surface, seeded from current config so callers can read these
-- even if setup() never ran. Re-seeded by setup() when opts change them.
M.PICKERS = config.pickers
M.active = vim.g.active_picker or read_state() or config.default_picker

function M.setup(opts)
  if opts == nil then
    return
  end

  config = vim.tbl_deep_extend("force", config, opts)
  M.PICKERS = config.pickers
  M.active = vim.g.active_picker or read_state() or config.default_picker
end

local function load_picker(name)
  local ok, mod = pcall(require, "custom_file_selectors." .. name)
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
