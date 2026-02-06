local M = {}

function M.setup(opts)
  local settings = require("my_extensions.onediff.settings")
  local sidebar = require("my_extensions.onediff.sidebar")
  settings.apply(opts)
  sidebar.init()
  
  vim.api.nvim_create_user_command("OneDiff", M.toggle, { desc = "Toggle OneDiff" })
  vim.api.nvim_create_user_command("OneDiffOpen", M.open, { desc = "Open OneDiff" })
  vim.api.nvim_create_user_command("OneDiffOpenCurrent", M.open_current, { desc = "Open OneDiff with current file" })
  vim.api.nvim_create_user_command("OneDiffClose", M.close, { desc = "Close OneDiff" })
  vim.api.nvim_create_user_command("OneDiffRefresh", M.refresh, { desc = "Refresh OneDiff" })
  vim.api.nvim_create_user_command("OneDiffNextFile", M.goto_next_file, { desc = "Go to next changed file" })
  vim.api.nvim_create_user_command("OneDiffPrevFile", M.goto_prev_file, { desc = "Go to previous changed file" })
  vim.api.nvim_create_user_command("OneDiffNextChange", M.goto_next_change, { desc = "Go to next change" })
  vim.api.nvim_create_user_command("OneDiffPrevChange", M.goto_prev_change, { desc = "Go to previous change" })
  vim.api.nvim_create_user_command("OneDiffFocusSidebar", M.focus_sidebar, { desc = "Focus sidebar" })
  vim.api.nvim_create_user_command("OneDiffToggleSidebar", M.toggle_sidebar, { desc = "Toggle sidebar" })
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

function M.open_current()
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")

  if session.is_open() then
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  
  session.start(current_file)
  sidebar.show()
  display.render_current()
end

function M.telescope_git_status()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")
  
  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end
  
  local git_root = git_ops.get_root()
  if not git_root then
    vim.notify("OneDiff: Not in a git repository", vim.log.levels.WARN)
    return
  end
  
  require("telescope.builtin").git_status({
    attach_mappings = function(_, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      
      map("i", "<CR>", function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          local selected_path = selection.value
          local files = session.get_files()
          
          for i, file in ipairs(files) do
            if file.path == selected_path then
              session.set_current_index(i)
              sidebar.render()
              display.render_current()
              return
            end
          end
          
          vim.notify("OneDiff: Selected file not in changed files list", vim.log.levels.WARN)
        end
      end)
      
      map("n", "<CR>", function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          local selected_path = selection.value
          local files = session.get_files()
          
          for i, file in ipairs(files) do
            if file.path == selected_path then
              session.set_current_index(i)
              sidebar.render()
              display.render_current()
              return
            end
          end
          
          vim.notify("OneDiff: Selected file not in changed files list", vim.log.levels.WARN)
        end
      end)
      
      return true
    end
  })
end

return M
