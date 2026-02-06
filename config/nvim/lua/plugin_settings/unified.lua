require('unified').setup({
  signs = {
    add = "│",
    delete = "│",
    change = "│",
  },
  highlights = {
    add = "DiffAdd",
    delete = "DiffDelete",
    change = "DiffChange",
  },
  line_symbols = {
    add = "+",
    delete = "-",
    change = "~",
  },
  auto_refresh = true,
})

local actions = require('unified.hunk_actions')

vim.keymap.set('n', '<leader>ud', require('unified').toggle, { desc = 'Toggle unified diff' })

vim.keymap.set('n', ']h', function() require('unified.navigation').next_hunk() end, { desc = 'Next hunk' })
vim.keymap.set('n', '[h', function() require('unified.navigation').previous_hunk() end, { desc = 'Previous hunk' })

vim.keymap.set('n', '<leader>gs', actions.stage_hunk,   { desc = 'Unified: Stage hunk' })
vim.keymap.set('n', '<leader>gu', actions.unstage_hunk, { desc = 'Unified: Unstage hunk' })
vim.keymap.set('n', '<leader>gr', actions.revert_hunk,  { desc = 'Unified: Revert hunk' })
