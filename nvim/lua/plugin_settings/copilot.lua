require("copilot").setup({
  panel = { enabled = false },
  suggestion = {
    enabled = false,
    auto_trigger = false,
    debounce = 75,
    keymap = {
      accept = "<c-j>",
      accept_word = false,
      accept_line = false,
      next = "<A-n>",
      prev = "<A-p>",
      dismiss = "<C-]>",
    },
  },
  -- copilot_node_command = 'node', -- Node.js version must be > 18.x
  -- server_opts_overrides = {},
})

-- require("copilot") --.setup({})
