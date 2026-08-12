if vim.g.loaded_ack == 1 then
  return
end
vim.g.loaded_ack = 1

-- Commands are registered up front but resolve their implementation on the
-- first invocation, so startup only pays for this file and the spec table.
for _, spec in ipairs(require("ack.commands").specs) do
  vim.api.nvim_create_user_command(spec.name, function(cmd_opts)
    require("ack").dispatch(spec, cmd_opts)
  end, { nargs = "*", bang = true, complete = spec.complete })
end
