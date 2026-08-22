-- CPU load from the raw per-core tick counters, as the busiest single core
-- and the mean across all of them.
--
-- hs.host.cpuUsage() would hand the percentages over ready-made, but it
-- blocks Hammerspoon for 100ms while it takes its own two samples — measured
-- at 101ms a call against 0.03ms for the raw counters. Diffing across
-- refreshes also widens the window from 100ms to the whole interval, so a
-- burst between two refreshes still shows up.
--
-- One sampler per consumer: the previous tick counters are the baseline every
-- reading is a delta against, and two consumers sharing one would each
-- consume the other's span and report load nobody experienced.
--
-- Usage:
--   local cpuTicks = require("cpu_ticks")
--   local sampler = cpuTicks.new()
--   local busiest, mean = sampler.usagePercents()

local M = {}

-- Share of one core's ticks spent doing anything but idling, over the span
-- between the two samples. nil when the counters did not move, which is what
-- a wrapped or reset counter looks like.
local function coreActivePercent(core, previous)
  local activeTicks = (core.user - previous.user) + (core.system - previous.system)
    + (core.nice - previous.nice)
  local totalTicks = activeTicks + (core.idle - previous.idle)

  if totalTicks <= 0 then
    return nil
  end

  return 100 * activeTicks / totalTicks
end

-- A sampler holding the tick counters from its own previous reading.
function M.new()
  local previousTicks = nil
  local sampler = {}

  -- Busiest single core and the mean across all of them: one pegged core is
  -- what a single-threaded build looks like, and the mean alone hides it.
  -- Both are nil on the first reading, which has no earlier sample to diff
  -- against.
  function sampler.usagePercents()
    local ticks = hs.host.cpuUsageTicks()
    local previous = previousTicks
    previousTicks = ticks

    if ticks == nil or previous == nil or previous.n ~= ticks.n then
      return nil, nil
    end

    local busiest = nil
    local total = 0
    local counted = 0

    for index = 1, ticks.n do
      local percent = coreActivePercent(ticks[index], previous[index])

      if percent ~= nil then
        total = total + percent
        counted = counted + 1

        if busiest == nil or percent > busiest then
          busiest = percent
        end
      end
    end

    if counted == 0 then
      return nil, nil
    end

    return busiest, total / counted
  end

  return sampler
end

return M
