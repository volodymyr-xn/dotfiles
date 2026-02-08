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

local ICON_PLUS = "󰐕"
local ICON_MINUS = "󰍴"
local ICON_NEW = "󰫻"

local function get_file_status_icon(file)
  local status = file.status
  local insertions = file.insertions or 0
  local deletions = file.deletions or 0

  if status == "added" or status == "untracked" then
    return ICON_NEW, "OneDiffStatusAdded"
  elseif status == "deleted" then
    return "D", "OneDiffStatusDeleted"
  elseif status == "modified" or status == "renamed" then
    if insertions > 0 and deletions > 0 then
      return ICON_PLUS .. " " .. ICON_MINUS, "mixed"
    elseif deletions > 0 then
      return ICON_MINUS, "OneDiffStatusDeleted"
    elseif insertions > 0 then
      return ICON_PLUS, "OneDiffStatusAdded"
    end
    return "M", "OneDiffStatusModified"
  end
  return "?", "OneDiffStatusUntracked"
end

local function get_folder_icon(is_collapsed)
  if is_collapsed then
    return "", "OneDiffFolderIcon"
  else
    return "", "OneDiffFolderIconOpen"
  end
end

local function get_folder_status(folder_path, files, is_collapsed, collapsed_folders)
  if not is_collapsed then
    return "   ", "Normal"
  end

  local has_deletions = false
  local has_additions = false
  local has_new = false
  local has_deleted = false

  for _, file in ipairs(files) do
    if file.path:find("^" .. vim.pesc(folder_path) .. "/") then
      if file.status == "added" or file.status == "untracked" then
        has_new = true
      elseif file.status == "deleted" then
        has_deleted = true
      elseif file.status == "modified" or file.status == "renamed" then
        local deletions = file.deletions or 0
        local insertions = file.insertions or 0
        if deletions > 0 then
          has_deletions = true
        end
        if insertions > 0 then
          has_additions = true
        end
      end
    end
  end

  if has_deleted then
    return "D", "OneDiffStatusDeleted"
  elseif has_additions and has_deletions then
    return ICON_PLUS .. " " .. ICON_MINUS, "mixed"
  elseif has_deletions then
    return ICON_MINUS, "OneDiffStatusDeleted"
  elseif has_new then
    return ICON_NEW, "OneDiffStatusAdded"
  elseif has_additions then
    return ICON_PLUS, "OneDiffStatusAdded"
  end
  return "   ", "Normal"
end

function M.init()
  vim.api.nvim_set_hl(0, "OneDiffPanelTitle", { fg = "#cdd6f4", bold = true, default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelCount", { fg = "#6c7086", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelPath", { fg = "#6c7086", italic = true, default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelFileName", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelSelected", { link = "Type", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelInsertions", { fg = "#a6e3a1", default = true })
  vim.api.nvim_set_hl(0, "OneDiffPanelDeletions", { fg = "#f38ba8", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderName", { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderIcon", { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderIconOpen", { link = "Directory", default = true })
  vim.api.nvim_set_hl(0, "OneDiffFolderArrow", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "OneDiffNonText", { fg = "#6c7086", default = true })
  vim.api.nvim_set_hl(0, "OneDiffCursorLine", { bg = "#313244", default = true })
  vim.api.nvim_set_hl(0, "OneDiffStatusModified", { fg = "#f5a97f", default = true })
  vim.api.nvim_set_hl(0, "OneDiffStatusAdded", { fg = "#a6da95", default = true })
  vim.api.nvim_set_hl(0, "OneDiffStatusDeleted", { fg = "#ed8796", default = true })
  vim.api.nvim_set_hl(0, "OneDiffStatusUntracked", { fg = "#8aadf4", default = true })
  vim.api.nvim_set_hl(0, "OneDiffTreeIndent", { fg = "#6c7086", default = true })
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
    local all_wins = vim.api.nvim_list_wins()
    local valid_wins = 0
    for _, w in ipairs(all_wins) do
      if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == "" then
        valid_wins = valid_wins + 1
      end
    end
    
    if valid_wins > 1 then
      api.nvim_win_close(win, true)
    end
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
    M.render_tree(tree, lines, hl_marks, line_idx, 0, current_idx, files)
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

local function count_children(node)
  local dir_count = 0
  for _ in pairs(node.children) do
    dir_count = dir_count + 1
  end
  return dir_count, #node.files
end

local function get_single_child_dir(node)
  local dir_count, file_count = count_children(node)
  if dir_count == 1 and file_count == 0 then
    for _, child in pairs(node.children) do
      return child
    end
  end
  return nil
end

local function collect_chain(node)
  local chain = { node }
  local current = node
  while true do
    local single_child = get_single_child_dir(current)
    if single_child then
      table.insert(chain, single_child)
      current = single_child
    else
      break
    end
  end
  return chain
end

function M.render_tree(node, lines, hl_marks, start_line, depth, current_idx, all_files)
  local line_idx = start_line

  local sorted_dirs = {}
  for name, child in pairs(node.children) do
    table.insert(sorted_dirs, { name = name, node = child })
  end
  table.sort(sorted_dirs, function(a, b) return a.name < b.name end)

  local rendered_paths = {}

  for _, dir in ipairs(sorted_dirs) do
    if rendered_paths[dir.node.path] then
      goto continue
    end

    local chain = collect_chain(dir.node)
    local last_node = chain[#chain]
    local display_name

    if #chain > 1 then
      local names = {}
      for _, n in ipairs(chain) do
        table.insert(names, n.name)
      end
      display_name = table.concat(names, "/")
    else
      display_name = dir.name
    end

    for _, n in ipairs(chain) do
      rendered_paths[n.path] = true
    end

    local is_collapsed = M.collapsed_folders[last_node.path] == true
    local arrow = is_collapsed and ">" or "˅"
    local folder_icon, folder_icon_hl = get_folder_icon(is_collapsed)
    local status_icon, status_hl = get_folder_status(last_node.path, all_files, is_collapsed, M.collapsed_folders)

    local tree_indent = string.rep("  ", depth)
    local status_display_width = vim.fn.strdisplaywidth(status_icon)
    local status_padding = string.rep(" ", math.max(0, 3 - status_display_width))
    local folder_line = " " .. status_icon .. status_padding .. " " .. tree_indent .. arrow .. " " .. folder_icon .. " " .. display_name

    table.insert(lines, folder_line)
    M.folder_line_map[line_idx + 1] = last_node.path

    local col = 1
    if status_hl == "mixed" then
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #ICON_PLUS, hl = "OneDiffStatusAdded", priority = 200 })
      table.insert(hl_marks, { line = line_idx, col = col + #ICON_PLUS + 1, end_col = col + #ICON_PLUS + 1 + #ICON_MINUS, hl = "OneDiffStatusDeleted", priority = 200 })
    else
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #status_icon, hl = status_hl, priority = 200 })
    end

    col = 1 + #status_icon + #status_padding + 1 + #tree_indent
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #arrow, hl = "OneDiffFolderArrow", priority = 200 })

    col = col + #arrow + 1
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #folder_icon, hl = folder_icon_hl, priority = 200 })

    col = col + #folder_icon + 1
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #display_name, hl = "OneDiffFolderName" })

    line_idx = line_idx + 1

    if not is_collapsed then
      line_idx = M.render_tree(last_node, lines, hl_marks, line_idx, depth + 1, current_idx, all_files)
    end

    ::continue::
  end

  for _, item in ipairs(node.files) do
    local status_icon, status_hl = get_file_status_icon(item.file)
    local icon, icon_hl = get_file_icon(item.name)

    local is_selected = item.index == current_idx
    local file_hl = is_selected and "OneDiffPanelSelected" or "OneDiffPanelFileName"

    local tree_indent = string.rep("  ", depth)
    local insertions = item.file.insertions or 0
    local deletions = item.file.deletions or 0

    local stats_str = ""
    if insertions > 0 or deletions > 0 then
      stats_str = " " .. insertions .. ", " .. deletions
    end

    local status_display_width = vim.fn.strdisplaywidth(status_icon)
    local status_padding = string.rep(" ", math.max(0, 3 - status_display_width))
    local line = " " .. status_icon .. status_padding .. " " .. tree_indent .. icon .. " " .. item.name .. stats_str

    table.insert(lines, line)
    M.file_line_map[line_idx + 1] = item.index

    local col = 1
    if status_hl == "mixed" then
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #ICON_PLUS, hl = "OneDiffStatusAdded", priority = 200 })
      table.insert(hl_marks, { line = line_idx, col = col + #ICON_PLUS + 1, end_col = col + #ICON_PLUS + 1 + #ICON_MINUS, hl = "OneDiffStatusDeleted", priority = 200 })
    else
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #status_icon, hl = status_hl, priority = 200 })
    end

    col = 1 + #status_icon + #status_padding + 1 + #tree_indent
    if icon_hl then
      table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #icon, hl = icon_hl })
    end

    col = col + #icon + 1
    table.insert(hl_marks, { line = line_idx, col = col, end_col = col + #item.name, hl = file_hl, priority = 150 })

    if #stats_str > 0 then
      local stats_start = col + #item.name
      local comma_pos = stats_str:find(",")
      if comma_pos then
        table.insert(hl_marks, { line = line_idx, col = stats_start, end_col = stats_start + comma_pos, hl = "OneDiffPanelInsertions", priority = 150 })
        table.insert(hl_marks, { line = line_idx, col = stats_start + comma_pos, end_col = stats_start + #stats_str, hl = "OneDiffPanelDeletions", priority = 150 })
      end
    end

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
  local session = require("my_extensions.onediff.session")
  local win = session.get_sidebar_win()
  
  if M.collapsed_folders[folder_path] then
    M.collapsed_folders[folder_path] = nil
  else
    M.collapsed_folders[folder_path] = true
  end
  
  M.render()
  
  if win and api.nvim_win_is_valid(win) then
    for line_num, path in pairs(M.folder_line_map) do
      if path == folder_path then
        pcall(api.nvim_win_set_cursor, win, { line_num, 0 })
        break
      end
    end
  end
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

function M.open_file_keep_focus()
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
    local sidebar_win = session.get_sidebar_win()
    session.set_current_index(file_idx)
    M.render()
    display.render_current()
    
    if sidebar_win and api.nvim_win_is_valid(sidebar_win) then
      api.nvim_set_current_win(sidebar_win)
    end
  end
end

function M.open_original_file()
  local session = require("my_extensions.onediff.session")
  local git_ops = require("my_extensions.onediff.git_ops")
  local diff_parse = require("my_extensions.onediff.diff_parse")

  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local folder_path = M.get_folder_at_line(line_num)
  if folder_path then
    M.toggle_folder(folder_path)
    return
  end

  local file_idx = M.get_file_at_line(line_num)
  if file_idx then
    local files = session.get_files()
    local file = files[file_idx]
    
    if file then
      local git_root = git_ops.get_root()
      local full_path = git_root and (git_root .. '/' .. file.path) or file.path
      
      local target_line = 1
      local target_col = 0
      
      local current_file_idx = session.get_current_index()
      if current_file_idx == file_idx then
        local diff_buf = session.get_diff_buf()
        if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == diff_buf then
              local pos = vim.api.nvim_win_get_cursor(win)
              target_line = pos[1]
              target_col = pos[2]
              break
            end
          end
        end
      else
        if file.status ~= "untracked" and file.status ~= "deleted" then
          local base_ref = session.get_base_ref()
          local diff_text = git_ops.get_file_diff(file.path, base_ref)
          local hunks = diff_parse.parse_hunks(diff_text)
          
          if hunks and #hunks > 0 then
            local change_blocks = diff_parse.get_change_lines_in_buffer(hunks)
            if #change_blocks > 0 then
              target_line = change_blocks[1].start
            end
          end
        end
      end
      
      vim.cmd('tabnew ' .. vim.fn.fnameescape(full_path))
      
      local new_win = vim.api.nvim_get_current_win()
      vim.wo[new_win].number = true
      vim.wo[new_win].relativenumber = false
      vim.wo[new_win].signcolumn = "yes"
      
      local new_buf = vim.api.nvim_get_current_buf()
      local line_count = vim.api.nvim_buf_line_count(new_buf)
      if target_line >= 1 and target_line <= line_count then
        vim.api.nvim_win_set_cursor(0, { target_line, target_col })
        vim.cmd("normal! zz")
      end
    end
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

  vim.keymap.set("n", keymaps.select, M.open_file_keep_focus, opts)
  vim.keymap.set("n", keymaps.refresh, onediff.refresh, opts)
  vim.keymap.set("n", "q", onediff.open_file_picker, opts)

  vim.keymap.set("n", "o", M.open_original_file, opts)
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

  vim.keymap.set("n", "h", "<Nop>", opts)
  vim.keymap.set("n", "l", "<Nop>", opts)

  vim.keymap.set("n", "<Tab>", function()
    local session = require("my_extensions.onediff.session")
    session.focus_diff_window()
    onediff.goto_next_change()
  end, opts)

  vim.keymap.set("n", "<S-Tab>", function()
    local session = require("my_extensions.onediff.session")
    session.focus_diff_window()
    onediff.goto_prev_change()
  end, opts)

  vim.keymap.set("n", "<C-i>", function()
    local session = require("my_extensions.onediff.session")
    session.focus_diff_window()
    onediff.goto_next_change()
  end, opts)

  vim.keymap.set("n", "<C-o>", function()
    local session = require("my_extensions.onediff.session")
    session.focus_diff_window()
    onediff.goto_prev_change()
  end, opts)

  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse_pos = vim.fn.getmousepos()
    if mouse_pos.winid == api.nvim_get_current_win() then
      local buf = api.nvim_get_current_buf()
      local line_count = api.nvim_buf_line_count(buf)
      if mouse_pos.line >= 1 and mouse_pos.line <= line_count then
        api.nvim_win_set_cursor(0, { mouse_pos.line, 0 })
        M.open_file_keep_focus()
      end
    end
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
