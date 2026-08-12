local M = {}

-- Single source of truth for the user commands: `plugin/ack.lua` registers
-- them and `ack.dispatch` routes each one back to its handler. `grepcmd` is
-- the Vim command the search runs through (the leading `l` is what marks a
-- search as location-list bound), `suffix` is appended after the bang.
M.specs = {
  { name = "Ack", grepcmd = "grep", handler = "ack", complete = "file" },
  { name = "AckAdd", grepcmd = "grepadd", handler = "ack", complete = "file" },
  { name = "AckFromSearch", grepcmd = "grep", handler = "ack_from_search", complete = "file" },
  { name = "LAck", grepcmd = "lgrep", handler = "ack", complete = "file" },
  { name = "LAckAdd", grepcmd = "lgrepadd", handler = "ack", complete = "file" },
  { name = "AckFile", grepcmd = "grep", handler = "ack", suffix = " -g", complete = "file" },
  { name = "AckHelp", grepcmd = "grep", handler = "ack_help", complete = "help" },
  { name = "LAckHelp", grepcmd = "lgrep", handler = "ack_help", complete = "help" },
  { name = "AckWindow", grepcmd = "grep", handler = "ack_window" },
  { name = "LAckWindow", grepcmd = "lgrep", handler = "ack_window" },
}

return M
