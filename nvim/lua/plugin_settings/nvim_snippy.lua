require('snippy').setup({
  mappings = {
    i = {
      ['<C-k>'] = 'expand_or_advance',
      ['<C-K>'] = 'previous',
    },
    -- nx = {
    --   ['<leader>x'] = 'cut_text',
    -- },
  },

  expand_options = {
    i = function()
      return true
    end
  }
})

-- local mappings = require('snippy.mapping')
-- vim.keymap.set('i', '<C-k>', mappings.expand_or_advance('<C-k>'))
-- vim.keymap.set('s', '<Tab>', mappings.next('<Tab>'))
-- vim.keymap.set({ 'i', 's' }, '<S-Tab>', mappings.previous('<S-Tab>'))
-- vim.keymap.set('x', '<Tab>', mappings.cut_text, { remap = true })
-- vim.keymap.set('n', 'g<Tab>', mappings.cut_text, { remap = true })