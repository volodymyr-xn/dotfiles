-- Run / lint helpers for Ren'Py projects, driven through a Vimux tmux pane.
-- The SDK launcher and project root are auto-detected so no path is hardcoded.

local M = {}

-- Locate the Ren'Py SDK launcher: $RENPY_SDK/renpy.sh first, then bare PATH.
local function renpy_sh()
  local sdk = vim.env.RENPY_SDK

  if sdk and sdk ~= "" then
    local candidate = sdk .. "/renpy.sh"

    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  if vim.fn.executable("renpy.sh") == 1 then
    return "renpy.sh"
  end

  return nil
end

-- Nearest ancestor directory holding a `game/` folder — the Ren'Py project root.
local function project_root()
  local buffer_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local game = vim.fs.find("game", {
    path = buffer_dir,
    upward = true,
    type = "directory",
  })[1]

  if game then
    return vim.fs.dirname(game)
  end

  return nil
end

-- Send `renpy.sh <project_root> <subcommand>` to a Vimux pane, warning on
-- missing SDK / project instead of running a broken command.
local function send(subcommand)
  local launcher = renpy_sh()
  if not launcher then
    vim.notify(
      "Ren'Py SDK not found. Set $RENPY_SDK or put renpy.sh on PATH.",
      vim.log.levels.ERROR
    )
    return
  end

  local root = project_root()
  if not root then
    vim.notify(
      "No Ren'Py project found (no `game/` dir above this file).",
      vim.log.levels.ERROR
    )
    return
  end

  local command = string.format(
    "%s %s %s",
    vim.fn.shellescape(launcher),
    vim.fn.shellescape(root),
    subcommand
  )

  vim.fn.VimuxRunCommand(command)
end

-- Launch the current project in the Ren'Py player.
function M.run()
  send("run")
end

-- Run Ren'Py's built-in linter over the current project.
function M.lint()
  send("lint")
end

return M
