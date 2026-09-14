-- Open the entry under the cursor but keep focus in the quickfix window
for _, key in ipairs({ "o", "i" }) do
  vim.keymap.set("n", key, "<CR><C-w>p", {
    buffer = true,
    desc = "Open quickfix entry, stay in quickfix",
  })
end
