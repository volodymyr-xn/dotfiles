require('local-highlight').setup({
  file_types = {'ruby', 'javascript', 'html'},
  hlgroup = 'LocalHighlightMatch',
  cw_hlgroup = nil,
})

vim.cmd [[
  hi LocalHighlightMatch guibg=#2e3345
]]
