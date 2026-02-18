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
  vim.api.nvim_create_user_command("OneDiffToggleInstance", M.toggle_instance, { desc = "Toggle OneDiff instance" })
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

  sidebar.hide()
  display.clear_all()
  session.stop()

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative == "" then
        vim.wo[win].number = true
      end
    end
  end
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

local function select_file_and_render(selected_path)
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local display = require("my_extensions.onediff.display")
  
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

local function telescope_picker()
  local ok, telescope = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("OneDiff: Telescope not available", vim.log.levels.ERROR)
    return
  end
  
  telescope.git_status({
    attach_mappings = function(_, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      
      map("i", "<CR>", function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          select_file_and_render(selection.value)
        end
      end)
      
      map("n", "<CR>", function(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          select_file_and_render(selection.value)
        end
      end)
      
      return true
    end
  })
end

local function fzf_lua_picker()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("OneDiff: fzf-lua not available", vim.log.levels.ERROR)
    return
  end
  
  fzf_lua.git_status({
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          local file_line = selected[1]
          local selected_path = file_line:match("^%S+%s+(.+)$")
          if selected_path then
            select_file_and_render(selected_path)
          end
        end
      end,
    },
  })
end

function M.open_file_picker()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  local settings = require("my_extensions.onediff.settings")
  
  if not session.is_open() then
    vim.notify("OneDiff: Not active", vim.log.levels.WARN)
    return
  end
  
  local git_root = git_ops.get_root()
  if not git_root then
    vim.notify("OneDiff: Not in a git repository", vim.log.levels.WARN)
    return
  end
  
  local picker = settings.get("picker") or "telescope"
  
  if picker == "fzf-lua" or picker == "fzf_lua" then
    fzf_lua_picker()
  elseif picker == "telescope" then
    telescope_picker()
  else
    vim.notify("OneDiff: Unknown picker '" .. picker .. "'. Use 'telescope' or 'fzf-lua'", vim.log.levels.ERROR)
  end
end

function M.toggle_instance()
  local session = require("my_extensions.onediff.session")
  local current_buf = vim.api.nvim_get_current_buf()
  
  if vim.b[current_buf].is_onediff_buffer or vim.b[current_buf].onediff_instance_id then
    local instance = session.get_instance_for_buffer(current_buf)
    if instance then
      M.close()
    end
  else
    local current_pwd = vim.fn.getcwd()
    local existing_instance = session.find_instance_by_working_dir(current_pwd)
    
    if existing_instance then
      session.focus_instance(existing_instance)
    else
      M.open()
    end
  end
end

function M.open_or_focus_and_refresh()
  local session = require("my_extensions.onediff.session")
  local sidebar = require("my_extensions.onediff.sidebar")
  local current_buf = vim.api.nvim_get_current_buf()
  
  if vim.b[current_buf].is_onediff_buffer or vim.b[current_buf].onediff_instance_id then
    M.refresh()
  else
    local current_pwd = vim.fn.getcwd()
    local existing_instance = session.find_instance_by_working_dir(current_pwd)
    
    if existing_instance then
      session.focus_instance(existing_instance)
      sidebar.show()
      M.refresh()
    else
      M.open()
    end
  end
end

function M.reload_current_file()
  local session = require("my_extensions.onediff.session")
  local display = require("my_extensions.onediff.display")
  local sidebar = require("my_extensions.onediff.sidebar")
  
  if not session.is_open() then
    return
  end
  
  display.render_current()
  sidebar.render()
end

function M.open_current_file_in_new_tab()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  
  if not session.is_open() then
    return
  end
  
  local current_file = session.get_current_file()
  if not current_file then
    vim.notify("OneDiff: No file selected", vim.log.levels.WARN)
    return
  end
  
  if current_file.status == "deleted" then
    vim.notify("OneDiff: Cannot open deleted file", vim.log.levels.WARN)
    return
  end
  
  local git_root = git_ops.get_root()
  if not git_root then
    vim.notify("OneDiff: Not in a git repository", vim.log.levels.ERROR)
    return
  end
  
  local full_path = git_root .. "/" .. current_file.path
  vim.cmd("tabnew " .. vim.fn.fnameescape(full_path))
end

return M
