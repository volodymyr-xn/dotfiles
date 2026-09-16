-- Keeps the Colima VM from quietly parking several gigabytes of macOS RAM.
--
-- `vmType: vz` backs the guest with one host mapping that only ever grows.
-- Every page Linux touches -- a Kamal build, an image pull, plain page
-- cache -- stays resident in the Virtualization.framework process for the
-- life of the VM, because the framework offers no free-page-reporting
-- balloon to hand freed pages back. Dropping caches inside the guest is
-- measurably useless here: the guest fell to ~600MB while the host process
-- still held 6.6GB. Restarting the VM is the only lever.
--
-- So this is a timer that restarts Colima, which is a rude thing to do
-- unannounced. The decision of whether the moment is safe is not made here:
-- bin/c-colima-trim-when-idle owns it and exits silently when the VM is
-- small enough or something is still building. This file owns only the
-- cadence and telling the user after the fact.

local TRIM_SCRIPT = os.getenv("HOME") .. "/dotfiles/bin/c-colima-trim-when-idle"

-- Checked four times an hour. The condition it is polling -- a VM grown
-- past its threshold with no build running -- changes on the scale of a
-- deploy, and each check is two docker calls, so anything tighter is spend
-- without a payoff.
local CHECK_INTERVAL_SECONDS = 15 * 60

-- A login shell, because the script reaches for `docker`, `colima` and
-- c-colima-restart by bare name and hs.task starts with a PATH that has
-- neither Homebrew nor ~/dotfiles/bin on it.
local SHELL = "/bin/bash"

-- nf-md-memory — marks the notification as being about reclaimed RAM.
local ICON = "󰍛"

local checkTimer

-- Announce a completed trim. The script prints nothing at all when it
-- decides to do nothing, so empty output is the common case and must stay
-- silent; only a real restart is worth interrupting for.
--
-- subTitle is always set: macOS renders `title` in the subtitle slot when
-- subTitle is missing or empty, which would leave the bold line reading
-- just "Hammerspoon".
local function notifyTrimmed(exitCode, stdOut)
  if exitCode ~= 0 then
    hs.notify.new({
      title = ICON .. " Colima trim failed",
      subTitle = "Run c-colima-trim by hand",
      informativeText = stdOut,
    }):send()

    return
  end

  if stdOut == nil or stdOut:match("^%s*$") then
    return
  end

  hs.notify.new({
    title = ICON .. " Colima restarted",
    subTitle = stdOut:match("reclaimed [^\n]*") or "Memory reclaimed",
  }):send()
end

-- One poll. hs.task rather than hs.execute so a restart -- which takes tens
-- of seconds -- never blocks Hammerspoon's main loop and freezes the
-- menubar items with it.
local function runTrimCheck()
  hs.task.new(SHELL, notifyTrimmed, { "-lc", TRIM_SCRIPT }):start()
end

checkTimer = hs.timer.doEvery(CHECK_INTERVAL_SECONDS, runTrimCheck)

-- Returned so the timer stays referenced: hs.timer objects are collected
-- once nothing holds them, and a module-local alone is not enough to
-- survive a garbage collection pass.
return { timer = checkTimer }
