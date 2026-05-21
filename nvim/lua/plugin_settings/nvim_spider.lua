local spider = require("spider")

spider.setup({})

-- Replace w/b/ge with subword-aware versions (camelCase, snake_case
-- boundaries). `e` is intentionally NOT remapped here — it's owned by
-- keymappings/navigation.lua (`e → E`, move to end of WORD).
vim.keymap.set({ "n", "o", "x" }, "w", function() spider.motion("w") end)
vim.keymap.set({ "n", "o", "x" }, "b", function() spider.motion("b") end)
vim.keymap.set({ "n", "o", "x" }, "ge", function() spider.motion("ge") end)
