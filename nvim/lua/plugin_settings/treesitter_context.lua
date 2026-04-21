local context = require("treesitter-context")

-- Pin current function/class context at the top of the buffer when scrolled past
context.setup({
  max_lines = 3,
  trim_scope = "outer",
  mode = "cursor",
})
