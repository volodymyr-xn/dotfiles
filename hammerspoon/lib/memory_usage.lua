-- Memory actually claimed, split the way Activity Monitor's own memory tab
-- splits it. Stateless: a page count is an absolute reading, not a delta, so
-- unlike the tick and counter samplers this needs no baseline and no
-- instance.
--
-- Usage:
--   local memoryUsage = require("memory_usage")
--   local memory = memoryUsage.current()

local M = {}

-- App memory (anonymous pages minus what is purgeable on demand), what the
-- kernel has pinned, and what the compressor holds, plus their total.
-- Anonymous rather than active, because inactive anonymous pages still hold
-- app data; counting only the active ones undercounts by whatever the apps
-- have not touched lately.
--
-- nil when the page size did not resolve, which is what vmStat failing looks
-- like — the caller shows placeholders rather than a wrong figure.
function M.current()
  local stat = hs.host.vmStat()

  if stat == nil or stat.pageSize == nil then
    return nil
  end

  local pageSize = stat.pageSize
  local app = (stat.anonymousPages - stat.pagesPurgeable) * pageSize
  local wired = stat.pagesWiredDown * pageSize
  local compressed = stat.pagesUsedByVMCompressor * pageSize

  return {
    app = app,
    wired = wired,
    compressed = compressed,
    used = app + wired + compressed,
  }
end

return M
