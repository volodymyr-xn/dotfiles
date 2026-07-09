local npairs = require('nvim-autopairs')
local autopairs_utils = require('nvim-autopairs.utils')

-- `map_cr = false` yields the <CR> insert-mode mapping to vim-endwise,
-- which loads on `ft = { ruby, lua, ... }` (BufRead). Without this,
-- nvim-autopairs loads later on InsertEnter and overwrites endwise's
-- <CR>, breaking `def...end` auto-insertion in Ruby/Lua/etc.
npairs.setup({
  disable_filetype = { "TelescopePrompt" , "vim" },
  map_cr = false,
})

-- Block the closing " when a word char (latin, Cyrillic or digit) follows the
-- cursor, so typing " right before a word inserts a lone quote, not a pair.
-- `\k` (iskeyword) is used because Lua's `%w` never matches multibyte Cyrillic.
local function skip_quote_pair_before_word(opts)
  local next_char = autopairs_utils.text_sub_char(opts.line, opts.col, 1)

  if next_char ~= "" and vim.fn.matchstr(next_char, [[\k]]) ~= "" then
    return false
  end
end

-- Apply the guard to every rule whose opening pair is a double quote.
for _, rule in ipairs(npairs.get_rules('"')) do
  rule:with_pair(skip_quote_pair_before_word, 1)
end

-- require("ibl").setup({
--
-- })
-- require('nvim-ts-autotag').setup({
  -- filetypes = { "html" , "eruby" },
-- })
