-- A rolling window of power readings, answering the mean and the extremes
-- over it. What a burst actually cost is the mean of the last minute, not
-- whatever the instant reading happens to say when a menu opens.
--
-- One window per consumer: a second one pushing its own readings into a
-- shared window would move the mean under the first, so the samples are
-- per-instance.
--
-- Usage:
--   local powerWindow = require("power_window")
--   local window = powerWindow.new(30)
--   window.record(watts)
--   local mean = window.average()
--   local lowest, highest = window.range()

local M = {}

-- `sampleLimit` is how many readings the window holds — the caller knows its
-- own cadence, so the span in seconds is its business, not this module's.
function M.new(sampleLimit)
  -- The readings behind the rolling average, oldest first, with their
  -- running total: the mean is wanted on every refresh, and re-adding a
  -- dozen samples for it is work the sum already did.
  local samples = {}
  local total = 0
  local window = {}

  -- Take one reading into the window, dropping the oldest once it is full. A
  -- refresh that could not read power leaves the window untouched rather
  -- than recording a zero, which would drag the mean down.
  function window.record(watts)
    if watts == nil then
      return
    end

    samples[#samples + 1] = watts
    total = total + watts

    if #samples > sampleLimit then
      total = total - table.remove(samples, 1)
    end
  end

  -- Mean of the window, or nil until the first reading lands.
  function window.average()
    local count = #samples

    if count == 0 then
      return nil
    end

    return total / count
  end

  -- Floor and ceiling of the same window: the mean says what a stretch cost,
  -- these two say how spiky it was.
  function window.range()
    local lowest = nil
    local highest = nil

    for _, watts in ipairs(samples) do
      if lowest == nil or watts < lowest then
        lowest = watts
      end

      if highest == nil or watts > highest then
        highest = watts
      end
    end

    return lowest, highest
  end

  return window
end

return M
