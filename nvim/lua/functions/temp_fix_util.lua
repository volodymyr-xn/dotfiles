-- TEMP_FIX gate: true while today < expires_on ("YYYY-MM-DD"). After expiry returns false
-- and shows a one-shot warning so the caller-side workaround gets removed.
function TempFixActive(label, expires_on)
  local y, m, d = expires_on:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return false end

  local deadline = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  if os.time() < deadline then return true end

  vim.schedule(function()
    vim.notify("TEMP_FIX expired: " .. label .. " (" .. expires_on .. ")", vim.log.levels.WARN)
  end)
  return false
end

