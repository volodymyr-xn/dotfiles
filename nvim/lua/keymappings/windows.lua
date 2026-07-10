-- True when a window is floating: only floats carry a `relative` field.
local function is_floating(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

-- Focus the first focusable floating window; from inside one, go back to the
-- window it was opened from. `<C-w>hjkl` cannot reach floats — they are not
-- part of the split grid — so this is the only keyboard way in.
local function focus_floating_window()
  if is_floating(0) then
    vim.cmd("wincmd p")
    return
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)

    if config.relative ~= "" and config.focusable then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  vim.notify("[windows] no floating window open", vim.log.levels.INFO)
end

-- Close current window
vim.api.nvim_set_keymap('n', '<C-c>', '<C-w>q', { noremap = true, desc = "Close window" })

-- Focus / unfocus the floating window
vim.keymap.set('n', 'sk', focus_floating_window, {
  noremap = true,
  silent = true,
  desc = "Focus floating window",
})

-- Maximize current window
vim.api.nvim_set_keymap('n', '"', '<C-W>|<C-W>_', { noremap = true, desc = "Maximize window" })

-- Re-balance all window sizes equally
vim.api.nvim_set_keymap('n', '=', '<C-W>=', { noremap = true, desc = "Balance windows" })

-- Toggle zoom on current window (custom command)
vim.api.nvim_set_keymap('n', 'm', ':ToggleCurrentWindowZoom<CR>', { noremap = true, silent = true, desc = "Toggle window zoom" })

-- Resize windows by 5 columns/rows
vim.api.nvim_set_keymap('n', '<', '<C-w>5<', { noremap = true, desc = "Decrease window width" })
vim.api.nvim_set_keymap('n', '>', '<C-w>5>', { noremap = true, desc = "Increase window width" })
vim.api.nvim_set_keymap('n', '+', '<C-w>5+', { noremap = true, desc = "Increase window height" })
vim.api.nvim_set_keymap('n', '_', '<C-w>5-', { noremap = true, desc = "Decrease window height" })

-- Open new tab
vim.api.nvim_set_keymap('n', '<c-t>', '<esc>:tabnew<CR>', { silent = true, noremap = true, desc = "Open new tab" })

-- Tab navigation
vim.api.nvim_set_keymap('n', '<C-e>', ':tabnext<CR>', { noremap = true, silent = true, desc = "Next tab" })
vim.api.nvim_set_keymap('n', '<M-j>', ':tabnext<CR>', { noremap = true, silent = true, desc = "Next tab" })
vim.api.nvim_set_keymap('n', '<M-k>', ':tabprev<CR>', { noremap = true, silent = true, desc = "Previous tab" })
vim.keymap.set("n", "K", ":tabnext<CR>", { noremap = true, silent = true, desc = "Next tab" })

-- Jump to tab N by index
for i = 1, 9 do
  vim.api.nvim_set_keymap('n', '<C-w>'..i, i..'gt<CR>', { noremap = true, desc = "Go to tab " .. i })
  vim.api.nvim_set_keymap('n', '<Leader>'..i, i..'gt<CR>', { noremap = true, desc = "Go to tab " .. i })
end
