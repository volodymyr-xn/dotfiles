-- `map_cr = false` yields the <CR> insert-mode mapping to vim-endwise,
-- which loads on `ft = { ruby, lua, ... }` (BufRead). Without this,
-- nvim-autopairs loads later on InsertEnter and overwrites endwise's
-- <CR>, breaking `def...end` auto-insertion in Ruby/Lua/etc.
require('nvim-autopairs').setup({
  disable_filetype = { "TelescopePrompt" , "vim" },
  map_cr = false,
})

-- require("ibl").setup({
--
-- })
-- require('nvim-ts-autotag').setup({
  -- filetypes = { "html" , "eruby" },
-- })
