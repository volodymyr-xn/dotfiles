-- Git diff popup lazy-loader — defers requiring `my_plugins.git_diff_popup`
-- (~140 LOC) until `:GitDiffPopup` is invoked. The real module registers
-- the command on load, overriding the stub below; we then re-dispatch.
--
-- The `sd` keymap stays here as a cmdline shortcut to `:GitDiffPopup<CR>`
-- — it doesn't need the module to be loaded to take effect.

local loaded = false

local function ensure_loaded()
  if loaded then
    return
  end

  loaded = true
  require("my_plugins.git_diff_popup")
end

vim.api.nvim_create_user_command("GitDiffPopup", function()
  ensure_loaded()
  vim.cmd("GitDiffPopup")
end, {})

vim.keymap.set("n", "sd", ":GitDiffPopup<CR>", {
  noremap = true,
  silent = true,
  desc = "Show git diff popup",
})
