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
M.active = read_state() or config.default_picker

-- Persisted file is the single source of truth: with several nvim instances
-- open at once, an instance's in-memory M.active goes stale the moment
-- another instance switches picker. Re-read the file so cycling advances
-- from the real current value and calls honour the latest saved choice
-- everywhere, instead of clobbering it with a stale per-instance value.
local function resolve_active()
  local name = read_state() or M.active or config.default_picker
  M.active = name
  vim.g.active_picker = name
  return name
end

function M.setup(opts)
  if opts == nil then
    return
  end

  config = vim.tbl_deep_extend("force", config, opts)
  M.PICKERS = config.pickers
  M.active = read_state() or config.default_picker

  -- Sync in-memory/display state from the file when this instance regains
  -- focus, so a switch made in another instance is reflected here. Wrapped
  -- so the truthy return of resolve_active never deletes the autocmd.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("UltraselectPickerSync", { clear = true }),
    callback = function() resolve_active() end,
  })
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
  local picker = load_picker(resolve_active())
  if not picker then return end

  local fn = picker[action]
  if type(fn) == "function" then
    fn(...)
  elseif fn == nil then
    vim.notify("ultraselect: picker '" .. M.active .. "' does not implement action '" .. action .. "'", vim.log.levels.WARN)
  end
end

function M.cycle()
  local active = resolve_active()
  local current_idx = 1
  for i, name in ipairs(M.PICKERS) do
    if name == active then
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
