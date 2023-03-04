function IsCurrentWindowZoomed()
  if not vim.g.currentWindowZoomed then
    vim.g.currentWindowZoomed = false
  end

  if vim.g.currentWindowZoomed then
    return '          VIM WINDOW ZOOM            '
  else
    return ''
  end
end

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'horizon',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {IsCurrentWindowZoomed, 'fileformat', 'filetype'},
    lualine_y = {'progress'},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}

-- TODO: rewrite this for lualine
vim.cmd [[
  function! LighlineTabFilenameWithParentDir(n) abort
    let buflist = tabpagebuflist(a:n)
    let winnr = tabpagewinnr(a:n)
    let bufnum = buflist[winnr - 1]
    let bufname = expand('#'.bufnum.':t')
    let buffullname = expand('#'.bufnum.':a')
    " let buffullname = expand('#')
    " return buffullname
    " return substitute(buffullname, '.*/\([^/]\+/\)', '\1', '')
    if strlen(bufname)
      return substitute(buffullname, '.*/\([^/]\+/\)', '\1', '')
    else
      return strlen(bufname) ? bufname : '[No Name]'
    endif
  endfunction
]]
