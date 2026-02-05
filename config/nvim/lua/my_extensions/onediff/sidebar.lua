local M = {}

local api = vim.api

M.collapsed_folders = {}
M.folder_line_map = {}
M.file_line_map = {}

local function get_file_icon(filename)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local ext = filename:match("%.(%w+)$")
    local icon, hl = devicons.get_icon(filename, ext, { default = true })
    return icon or "", hl
  end
  return "", nil
end

local function get_git_status_hl(status)
  if status == "added" then
    return "DiffAdd"
  elseif status == "deleted" then
    return "DiffDelete"
  elseif status == "modified" then
    return "DiffChange"
  elseif status == "renamed" then
    return "DiffChange"
  end
  return "Normal"
end

local function get_status_letter(status)
  if status == "added" then
    return "A"
  elseif status == "deleted" then
    return "D"
  elseif status == "modified" then
    return "M"
  elseif status == "renamed" then
    return "R"
  end
  return "?"
end

function M.init()
  vim.api.nvim_set_hl(0, "OneDiffPanelTitle", { fg = "#cdd6f4", bold = true, default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelCount", { fg = "#6c7086", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelPath", { fg = "#6c7086", italic = true, default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelFileName", { fg = "#cdd6f4", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelSelected", { fg = "#cdd6f4", bold = true, default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelInsertions", { fg = "#a6e3a1", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelDeletions", { fg = "#f38ba8", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderName", { fg = "#89b4fa", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderSign", { fg = "#f9e2af", default = true })
  vim.api.nvim_set_hl(0, "OneDiffNonText", { fg = "#6c7086", default = true })
  vim.api.nvim_set_hl(0, "OneDiffCursorLine", { bg = "#313244", default = true })
end

function M.show()
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")

  if session.get_sidebar_win() and api.nvim_win_is_valid(session.get_sidebar_win()) then
    return
  end

  local width = settings.get("sidebar.width")

  vim.cmd("topleft " .. width .. "vsplit")
  local win = api.nvim_get_current_win()
  session.set_sidebar_win(win)

  local buf = M.create_buffer()
  session.set_sidebar_buf(buf)
  api.nvim_win_set_buf(win, buf)

  M.apply_win_options(win)
  M.render()
  M.setup_keymaps(buf)
  M.setup_autocmds(buf)

  vim.cmd("wincmd p")
end

function M.hide()
  local session = require("my_extensions.onediff.session")

  local win = session.get_sidebar_win()
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_close(win, true)
  end

  local buf = session.get_sidebar_buf()
  if buf and api.nvim_buf_is_valid(buf) then
    api.nvim_buf_delete(buf, { force = true })
  end

  session.set_sidebar_win(nil)
  session.set_sidebar_buf(nil)
end

function M.toggle()
  local session = require("my_extensions.onediff.session")

  local win = session.get_sidebar_win()
  if win and api.nvim_win_is_valid(win) then
    M.hide()
  else
    M.show()
  end
end

function M.focus()
  local session = require("my_extensions.onediff.session")

  local win = session.get_sidebar_win()
  if win and api.nvim_win_is_valid(win) then
    api.nvim_set_current_win(win)
  end
end

function M.create_buffer()
  local buf = api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "OneDiffPanel"

  api.nvim_buf_set_name(buf, "OneDiffPanel")

  return buf
end

function M.apply_win_options(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].spell = false
  vim.wo[win].list = false
  vim.wo[win].cursorline = true
  vim.wo[win].winfixwidth = true
  vim.wo[win].winhighlight = "CursorLine:OneDiffCursorLine"
end

function M.render()
  local session = require("my_extensions.onediff.session")
  local settings = require("my_extensions.onediff.settings")
  local git_ops = require("my_extensions.onediff.git_ops")

  local buf = session.get_sidebar_buf()
  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  local files = session.get_files()
  local current_idx = session.get_current_index()
  local ns = settings.get_ns()

  local lines = {}
  local hl_marks = {}

  local git_root = git_ops.get_root() or vim.fn.getcwd()
  local root_display = vim.fn.fnamemodify(git_root, ":~")
  if #root_display > 32 then
    root_display = "..." .. root_display:sub(-29)
  end

  table.insert(lines, root_display)
  table.insert(hl_marks, { line = 0, col = 0, end_col = #root_display, hl = "OneDiffPanelPath" })

  table.insert(lines, "")

  local changes_title = "Changes"
  local changes_count = "(" .. #files .. ")"
  table.insert(lines, changes_title .. " " .. changes_count)
  table.insert(hl_marks, { line = 2, col = 0, end_col = #changes_title, hl = "OneDiffPanelTitle" })
  table.insert(hl_marks, { line = 2, col = #changes_title + 1, end_col = #changes_title + 1 + #changes_count, hl = "OneDiffPanelCount" })

  if #files == 0 then
    table.insert(lines, "  No changes")
    table.insert(hl_marks, { line = 3, col = 0, end_col = 12, hl = "OneDiffPanelCount" })
  else
    M.file_line_map = {}
    M.folder_line_map = {}

    local tree = M.build_file_tree(files)
    local line_idx = #lines
    M.render_tree(tree, lines, hl_marks, line_idx, 0, current_idx)
  end

  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for _, mark in ipairs(hl_marks) do
    if mark.line < #lines then
      api.nvim_buf_set_extmark(buf, ns, mark.line, mark.col or 0, {
        end_col = mark.end_col,
        hl_group = mark.hl,
        priority = mark.priority or 100,
      })
    end
  end

  local win = session.get_sidebar_win()
  if win and api.nvim_win_is_valid(win) and current_idx > 0 then
    local target_line = M.get_file_line(current_idx)
    if target_line then
      pcall(api.nvim_win_set_cursor, win, { target_line, 0 })
    end
  end
end

function M.build_file_tree(files)
  local tree = { children = {}, files = {}, path = "" }

  for i, file in ipairs(files) do
    local parts = vim.split(file.path, "/")
    local current = tree
    local current_path = ""

    for j = 1, #parts - 1 do
      local dir_name = parts[j]
      current_path = current_path == "" and dir_name or (current_path .. "/" .. dir_name)
      if not current.children[dir_name] then
        current.children[dir_name] = { children = {}, files = {}, name = dir_name, path = current_path }
      end
      current = current.children[dir_name]
    end

    table.insert(current.files, {
      name = parts[#parts],
      file = file,
      index = i,
    })
  end

  return tree
end

function M.render_tree(node, lines, hl_marks, start_line, depth, current_idx)
  local line_idx = start_line

  local sorted_dirs = {}
  for name, child in pairs(node.children) do
    table.insert(sorted_dirs, { name = name, node = child })
  end
  table.sort(sorted_dirs, function(a, b) return a.name < b.name end)

  for _, dir in ipairs(sorted_dirs) do
    local indent = string.rep("  ", depth)
    local is_collapsed = M.collapsed_folders[dir.node.path] == true
    local folder_icon = is_collapsed and "" or ""
    local folder_line = indent .. folder_icon .. " " .. dir.name

    table.insert(lines, folder_line)

    M.folder_line_map[line_idx + 1] = dir.node.path

    local icon_start = #indent
    local icon_end = icon_start + #folder_icon
    table.insert(hl_marks, { line = line_idx, col = icon_start, end_col = icon_end, hl = "OneDiffFolderArrow", priority = 200 })

    local name_start = icon_end + 1
    local name_end = name_start + #dir.name
    table.insert(hl_marks, { line = line_idx, col = name_start, end_col = name_end, hl = "OneDiffFolderName" })

    line_idx = line_idx + 1

    if not is_collapsed then
      line_idx = M.render_tree(dir.node, lines, hl_marks, line_idx, depth + 1, current_idx)
    end
  end

  for _, item in ipairs(node.files) do
    local indent = string.rep("  ", depth)
    local status_letter = get_status_letter(item.file.status)
    local status_hl = get_git_status_hl(item.file.status)
    local icon, icon_hl = get_file_icon(item.name)

    local is_selected = item.index == current_idx
    local file_hl = is_selected and "OneDiffPanelSelected" or "OneDiffPanelFileName"

    local line = indent .. status_letter .. " " .. icon .. " " .. item.name

    table.insert(lines, line)

    M.file_line_map[line_idx + 1] = item.index

    local col = #indent
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + 1, hl = status_hl })

    col = col + 2
    if icon_hl then
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #icon, hl = icon_hl })
    end

    col = col + #icon + 1
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #item.name, hl = file_hl, priority = 150 })

    if is_selected then
      table.insert(hl_marks, { line = line_idx, col = 0, end_col = #line, hl = "OneDiffCursorLine", priority = 50 })
    end

    line_idx = line_idx + 1
  end

  return line_idx
end

function M.get_file_line(file_idx)
  if not M.file_line_map then
    return nil
  end

  for line, idx in pairs(M.file_line_map) do
    if idx == file_idx then
      return line
    end
  end

  return nil
end

function M.get_file_at_line(line_num)
  if not M.file_line_map then
    return nil
  end

  return M.file_line_map[line_num]
end

function M.get_folder_at_line(line_num)
  if not M.folder_line_map then
    return nil
  end
  return M.folder_line_map[line_num]
end

function M.toggle_folder(folder_path)
  if M.collapsed_folders[folder_path] then
    M.collapsed_folders[folder_path] = nil
  else
    M.collapsed_folders[folder_path] = true
  end
  M.render()
end

function M.select_item()
  local session = require("my_extensions.onediff.session")
  local display = require("my_extensions.onediff.display")

  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local folder_path = M.get_folder_at_line(line_num)
  if folder_path then
    M.toggle_folder(folder_path)
    return
  end

  local file_idx = M.get_file_at_line(line_num)
  if file_idx then
    session.set_current_index(file_idx)
    M.render()
    display.render_current()
  end
end

function M.select_file()
  M.select_item()
end

function M.collapse_all()
  local session = require("my_extensions.onediff.session")
  local files = session.get_files()
  local tree = M.build_file_tree(files)

  local function collect_folders(node)
    for _, child in pairs(node.children) do
      if child.path then
        M.collapsed_folders[child.path] = true
      end
      collect_folders(child)
    end
  end

  collect_folders(tree)
  M.render()
end

function M.expand_all()
  M.collapsed_folders = {}
  M.render()
end

function M.setup_keymaps(buf)
  local settings = require("my_extensions.onediff.settings")
  local keymaps = settings.get("keymaps.sidebar")
  local onediff = require("my_extensions.onediff")

  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", keymaps.select, M.select_item, opts)
  vim.keymap.set("n", keymaps.close, onediff.close, opts)
  vim.keymap.set("n", keymaps.refresh, onediff.refresh, opts)

  vim.keymap.set("n", "o", M.select_item, opts)
  vim.keymap.set("n", "za", function()
    local cursor = api.nvim_win_get_cursor(0)
    local folder_path = M.get_folder_at_line(cursor[1])
    if folder_path then
      M.toggle_folder(folder_path)
    end
  end, opts)

  vim.keymap.set("n", "zM", M.collapse_all, opts)
  vim.keymap.set("n", "zR", M.expand_all, opts)

  vim.keymap.set("n", "j", function()
    local cursor = api.nvim_win_get_cursor(0)
    local lines = api.nvim_buf_line_count(0)
    if cursor[1] < lines then
      api.nvim_win_set_cursor(0, { cursor[1] + 1, 0 })
    end
  end, opts)

  vim.keymap.set("n", "k", function()
    local cursor = api.nvim_win_get_cursor(0)
    if cursor[1] > 1 then
      api.nvim_win_set_cursor(0, { cursor[1] - 1, 0 })
    end
  end, opts)

  vim.keymap.set("n", "<Tab>", function()
    onediff.goto_next_file()
  end, opts)

  vim.keymap.set("n", "<S-Tab>", function()
    onediff.goto_prev_file()
  end, opts)
end

function M.setup_autocmds(buf)
  local group = api.nvim_create_augroup("OneDiffSidebar", { clear = true })

  api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      local session = require("my_extensions.onediff.session")
      session.set_sidebar_buf(nil)
      session.set_sidebar_win(nil)
    end,
  })
end

function M.refresh()
  local session = require("my_extensions.onediff.session")

  if not session.is_open() then
    return
  end

  M.render()
end

return M
