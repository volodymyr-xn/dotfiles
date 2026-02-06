local function find_diff_line_for_source_line(diff, target_line)
  local diff_line_num = 1
  local current_new_line = 0

  for _, line in ipairs(diff) do
    if line:match("^@@") then
      local new_start = line:match("%+(%d+)")
      if new_start then
        current_new_line = tonumber(new_start)
      end
    elseif line:match("^%-") then
      -- Deletion, don't increment current_new_line
    elseif line:match("^%+") then
      if current_new_line == target_line then
        return diff_line_num
      end
      current_new_line = current_new_line + 1
    else
      -- Context line
      if current_new_line == target_line then
        return diff_line_num
      end
      current_new_line = current_new_line + 1
    end
    diff_line_num = diff_line_num + 1
  end

  return nil
end

function GitDiffCurrentFilePopup()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("No file associated with this buffer", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Diff for current file
  local diff = vim.fn.systemlist("git diff -- " .. vim.fn.fnameescape(file))
  if #diff == 0 then
    vim.notify("No changes in current file", vim.log.levels.INFO)
    return
  end

  -- Scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'diff')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- vim.api.nvim_set_option_value("filetype", "diff", { buf = buf })

  -- 90% screen size
  local width  = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local row    = math.floor((vim.o.lines - height) / 2)
  local col    = math.floor((vim.o.columns - width) / 2)

  -- Floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = true,
    title = ' Git Diff ',
    title_pos = 'center'
  })

  -- Position cursor at current line if it has changes
  local target_diff_line = find_diff_line_for_source_line(diff, current_line)
  if target_diff_line then
    vim.api.nvim_win_set_cursor(win, {target_diff_line, 0})
  end

  --------------------------------------------------------------------
  -- FOCUS LOCKING
  --------------------------------------------------------------------

  local blocked_keys = {
    -- window navigation
    "<C-w>", "<C-w>h", "<C-w>j", "<C-w>k", "<C-w>l", "<C-w>w", "<C-w>W",
    "<C-w>p", "<C-w>t", "<C-w>b", "<C-w>c", "<C-w>o", "<C-w>q",
    "<C-w>s", "<C-w>v", "<C-w>n", "<C-w><C-w>",
    "<C-h>", "<C-j>", "<C-k>", "<C-l>",
    "<C-Up>", "<C-Down>", "<C-Left>", "<C-Right>",

    -- tab switching
    "<Tab>", "<S-Tab>",
    "gt", "gT", "<C-PageUp>", "<C-PageDown>",

    -- buffer switching
    "<C-^>", "<C-6>",

    -- jump list navigation
    "<C-o>", "<C-i>", "<C-t>",

    -- file navigation
    "gf", "gF", "<C-]>", "gd", "gD",

    -- marks
    "'", "`",

    -- other navigation
    "ZZ", "ZQ",
  }

  for _, key in ipairs(blocked_keys) do
    vim.keymap.set({ "n", "v", "i" }, key, "<Nop>", { buffer = buf, silent = true })
  end

  -- Block command mode completely
  vim.keymap.set({ "n", "v" }, ":", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set({ "n", "v" }, "Q", "<Nop>", { buffer = buf, silent = true })

  local close_popup = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Close popup bindings in git diff popup mode
  vim.keymap.set("n", "<Esc>", close_popup, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", close_popup, { buffer = buf, silent = true })
end

vim.api.nvim_create_user_command("GitDiffPopup", GitDiffCurrentFilePopup, {})

-- Show git diff in popup
-- vim.keymap.set('n', 'se', ':GitDiffPopup<CR>', { noremap = true, silent = true, desc = "Show git diff popup" })
-- vim.keymap.set('n', '<c-i>', '<ESC>', { noremap = true, silent = true, desc = "Show git diff popup" })
