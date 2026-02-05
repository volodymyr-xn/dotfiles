local M = {}

function M.setup(opts)
  local settings = require("my_extensions.onediff.settings")
  local sidebar = require("my_extensions.onediff.sidebar")
  settings.apply(opts)
  sidebar.init()
end

function M.open()
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")

  if session.is_open() then
    return
  end

  session.start()
  sidebar.show()
  display.render_current()
end

function M.close()
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")

  if not session.is_open() then
    return
  end

  display.clear_all()
  sidebar.hide()
  session.stop()
end

function M.toggle()
  local session = require("my_extensions.onediff.session")
  if session.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")

  if not session.is_open() then
    return
  end

  session.reload_files()
  sidebar.refresh()
  display.render_current()
end

function M.goto_next_file()
  local controls = require("my_extensions.onediff.controls")
  controls.next_file()
end

function M.goto_prev_file()
  local controls = require("my_extensions.onediff.controls")
  controls.prev_file()
end

function M.goto_next_change()
  local controls = require("my_extensions.onediff.controls")
  controls.next_change()
end

function M.goto_prev_change()
  local controls = require("my_extensions.onediff.controls")
  controls.prev_change()
end

function M.focus_sidebar()
  local sidebar = require("my_extensions.onediff.sidebar")
  sidebar.focus()
end

function M.toggle_sidebar()
  local sidebar = require("my_extensions.onediff.sidebar")
  sidebar.toggle()
end

return M
