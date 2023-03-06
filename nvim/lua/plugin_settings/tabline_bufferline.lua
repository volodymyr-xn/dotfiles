require("bufferline").setup({
  options = {
    mode = "tabs",
    numbers = "ordinal",
    name_formatter = function(buf)  -- buf contains:
      -- name                | str        | the basename of the active file
      -- path                | str        | the full path of the active file
      -- bufnr (buffer only) | int        | the number of the active buffer
      -- buffers (tabs only) | table(int) | the numbers of the buffers in the tab
      -- tabnr (tabs only)   | int        | the "handle" of the tab, can be converted to its ordinal number using: `vim.api.nvim_tabpage_get_number(buf.tabnr)`
      local parent_dir = vim.fn.fnamemodify(vim.fn.fnamemodify(buf.path, ':h'), ':t')
      return parent_dir .. '/' .. buf.name
    end,
    max_name_lenght = 40,
    -- tab_size = 20,
    truncate_names = false, -- whether or not tab names should be truncated
  }
})
