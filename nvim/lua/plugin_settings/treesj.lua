local treesj = require("treesj")

treesj.setup({
  use_default_keymaps = false,
})

-- Toggle between single-line and multi-line form using Treesitter syntax awareness
vim.keymap.set("n", "<leader>M", treesj.toggle, { desc = "Toggle split/join" })
