-- Interface byte counters turned into a throughput rate. The counters
-- themselves only ever climb, so a rate is the delta between two readings
-- over the time between them, and that means somebody has to hold the
-- previous reading — which is what this owns.
--
-- One tracker per stream of counters. Two consumers sharing a single
-- baseline would each subtract the other's reading and both report rates
-- that never happened, with nothing to signal it, so the baseline is
-- per-instance rather than per-module.
--
-- Usage:
--   local netCounters = require("net_counters")
--   local tracker = netCounters.new()
--   local uploadRate, downloadRate = tracker.rates(received, sent)

local M = {}

-- The interface counters are 32-bit and wrap every 4GB — a delta modulo
-- that is exact as long as under one wrap happens between two readings,
-- which at a two-second interval means anything short of a 11Gbit/s link.
local COUNTER_WRAP = 2 ^ 32

-- Bytes moved since the previous reading, unwrapping the 32-bit counter.
local function counterDelta(current, previous)
  if current >= previous then
    return current - previous
  end

  return current + COUNTER_WRAP - previous
end

-- A tracker holding the counters from its own previous reading.
function M.new()
  local previousCounters = nil
  local tracker = {}

  -- Upload and download rates in bytes per second, or nil on the first
  -- reading, when there is no earlier counter to subtract.
  --
  -- The elapsed time is measured rather than assumed to match the producer's
  -- interval: readings arrive when the scheduler gets to them, and at half a
  -- second that jitter is a visible share of the divisor.
  function tracker.rates(receivedBytes, sentBytes)
    if receivedBytes == nil or sentBytes == nil then
      return nil, nil
    end

    local previous = previousCounters
    local now = hs.timer.secondsSinceEpoch()
    previousCounters = { received = receivedBytes, sent = sentBytes, at = now }

    if previous == nil then
      return nil, nil
    end

    local elapsed = now - previous.at

    if elapsed <= 0 then
      return nil, nil
    end

    return counterDelta(sentBytes, previous.sent) / elapsed,
      counterDelta(receivedBytes, previous.received) / elapsed
  end

  return tracker
end

return M
