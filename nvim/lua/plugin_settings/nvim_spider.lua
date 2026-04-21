local spider = require("spider")

spider.setup({})

-- Replace w/e/b/ge with subword-aware versions (camelCase, snake_case boundaries)
vim.keymap.set({ "n", "o", "x" }, "w", function() spider.motion("w") end)
vim.keymap.set({ "n", "o", "x" }, "e", function() spider.motion("e") end)
vim.keymap.set({ "n", "o", "x" }, "b", function() spider.motion("b") end)
vim.keymap.set({ "n", "o", "x" }, "ge", function() spider.motion("ge") end)
