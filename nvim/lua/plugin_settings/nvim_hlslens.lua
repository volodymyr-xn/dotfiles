-- Wires hlslens into nvim-scrollbar's search handler. Calling this internally
-- runs hlslens.setup with a build_position_cb that pushes match positions to
-- scrollbar, so search hits appear as scrollbar marks. Must run after
-- scrollbar.setup; lazy `dependencies` in plugins_install.lua guarantees that.
require("scrollbar.handlers.search").setup({})

local kopts = { noremap = true, silent = true }

-- Word-under-cursor search forward + refresh lens (match index/total + scrollbar marks).
vim.keymap.set("n", "*", [[*<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Word-under-cursor search backward + refresh lens.
vim.keymap.set("n", "#", [[#<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Like `*` but without word boundaries.
vim.keymap.set("n", "g*", [[g*<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Like `#` but without word boundaries.
vim.keymap.set("n", "g#", [[g#<Cmd>lua require("hlslens").start()<CR>]], kopts)

-- Search forward + refresh lens (match index/total + scrollbar marks).
vim.keymap.set("n", "n", [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)

-- Search backward + refresh lens.
vim.keymap.set("n", "N", [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]], kopts)

-- Clears highlighting and stops the lens.
vim.keymap.set("n", "<Leader>l", "<Cmd>noh<CR><Cmd>lua require('hlslens').stop()<CR>", kopts)
