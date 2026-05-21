-- Neovim 0.12 redesign of cmdline + messages; replaces the legacy message
-- grid (no "Press ENTER" prompts, cmdline syntax highlighting, pager as a
-- real buffer reachable with g<). Experimental; revisit each minor release.
require("vim._core.ui2").enable({
  enable = true,
  msg = {
    -- Default message target: 'cmd' (cmdline) or 'msg' (ephemeral window).
    targets = "cmd",
    cmd = {
      -- Max expanded height for messages overflowing 'cmdheight'.
      height = 0.5,
    },
    dialog = {
      height = 0.5,
    },
    msg = {
      height = 0.5,
      -- Time (ms) a message stays visible in the floating msg window.
      timeout = 4000,
    },
    pager = {
      height = 1,
    },
  },
})
