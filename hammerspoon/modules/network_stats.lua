-- Menubar readout of what the machine is moving over its network: upload over
-- download for the interface the default route currently uses, refreshed on a
-- timer, with the interface's own details behind a click.
--
-- Its own item rather than a column of the sensors row, because throughput is
-- the spikiest reading on the bar and wants a cadence of its own: a rate is
-- only as good as the interval it was measured over, and the sensor figures
-- move by a digit where this one swings from "0 B/s" to "999 MB/s" and back
-- inside two seconds.
--
-- The two rates are stacked in the height of the bar the same way the sensor
-- columns are — menubar_row owns that drawing, so the two items are
-- indistinguishable in the bar — and the arrows are what name them: a glyph
-- says which direction a rate belongs to in less width than any word would.
--
-- The counters come from c-net-counters-macos, a small Swift helper that reads
-- the primary interface's AF_LINK counters (see
-- native_modules/macos/c-net-counters-macos.swift). It reports totals rather
-- than rates, because a rate needs two samples and it takes one; net_counters
-- owns the baseline that turns them into one.
--
-- Build the helper once with `dotfiles_setup/build_native_modules.sh`; until
-- then this shows placeholders rather than disappearing, so a missing binary
-- is visible.
--
-- Clicking the item opens a panel with everything the row has no width for:
-- the two rates spelled out, the interface's address, its Wi-Fi signal when it
-- has one, and the totals the rates were taken from.
-- The panel is a canvas rather than a menu, which is what buys it a refresh
-- while it is open; canvas_panel owns the surface, the placement and the
-- dismissal, and process_stats draws its own the same way.
--
-- There is no hide item in the panel: `hs -c 'require("network_stats").hide()'`
-- still works, and `show()` or a config reload brings the widget back.

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "network_stats" and "modules.network_stats" — two
-- package.loaded entries, and without this guard the second require runs the
-- body again and paints a second item in the bar.
local INSTANCE_KEY = "networkStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")
local canvasPanel = require("canvas_panel")
local lineStream = require("line_stream")
local menubarRow = require("menubar_row")
local netCounters = require("net_counters")
local statFormat = require("stat_format")
local statPanel = require("stat_panel")

local formatBytes = statFormat.bytes
local formatRate = statFormat.rate
local PLACEHOLDER = statFormat.PLACEHOLDER

-- Absolute path because hs.task does not consult the login shell's PATH,
-- which is where ~/dotfiles/bin_native/macos is added.
local NATIVE_DIRECTORY = os.getenv("HOME") .. "/dotfiles/bin_native/macos/"
local NETWORK_HELPER = NATIVE_DIRECTORY .. "c-net-counters-macos"

-- The helper streams a line per interval through lib/line_stream, which
-- carries why that beats spawning one per refresh.
--
-- A second is the cadence a throughput figure is readable at: half of it makes
-- the digits flicker faster than they can be read, and two of them average a
-- burst away. The row repaints per line rather than on a timer of its own —
-- with one stream feeding it, the line *is* the cadence.
local STREAM_INTERVAL_MILLISECONDS = 1000

-- How often a dead stream is noticed and restarted. Loose because a helper
-- that dies at all is the unexpected case — this is a backstop, not a poll.
local SUPERVISOR_SECONDS = 10

-- While the panel is open. Matched to the stream, so the sparkline gains a
-- slot per repaint rather than showing the same one twice.
local PANEL_REFRESH_SECONDS = STREAM_INTERVAL_MILLISECONDS / 1000

local UPLOAD_ICON = "arrow_up"
local DOWNLOAD_ICON = "arrow_down"

-- The reserved-width template below is measured in these, so the suffix has to
-- match the one stat_format puts on a rate.
local RATE_SUFFIX = "/s"

-- The column is reserved at the width of its widest reading and its figures
-- are right-aligned inside that. Rates swing several digits from one second to
-- the next, and without the reservation the item's own width would follow —
-- dragging every menubar item to its left sideways on every spike.
--
-- Eights because they are the widest digit in a proportional face.
local RATE_WIDTH_TEMPLATE = "888 MB" .. RATE_SUFFIX

-- hs.wifi.interfaceDetails costs about 55ms — it builds the scan cache and the
-- supported-channel list along with the signal, and there is no way to ask for
-- less. Far too much for the panel's own cadence, so the reading is kept and
-- reused: RSSI moves slowly enough that five seconds of it is still the truth.
local WIFI_REFRESH_SECONDS = 5

-- The usable span of a Wi-Fi signal, which is what the gauge is a share of.
-- Below the worst figure the link is unusable rather than weak, and above the
-- best one the extra dBm buy nothing.
local WORST_RSSI = -90
local BEST_RSSI = -50

-- Below these the signal is drawn in orange, then red: -70 is where a link
-- starts dropping rate, -80 is where it starts dropping packets.
local WARN_RSSI = -70
local CRITICAL_RSSI = -80

-- Separates the two figures of a detail line. Wider than a space on each side
-- because the two are different readings, not one phrase.
local DETAIL_SEPARATOR = "  ·  "

local NO_ADDRESS_TEXT = "No address"

-- nf-md-network_off — the banner glyph confirming the widget was hidden.
local HIDDEN_ICON = "󰲛"

local menu = hs.menubar.new()
local barRow = menubarRow.new()
local tracker = netCounters.new()

local streamTask = nil
local supervisorTimer = nil

-- The latest counters and the rates taken from them. One table reused rather
-- than replaced, so the panel always reads the reading of the moment.
local reading = {}

-- Plain-text mirror of what was last painted, for the `title` accessor.
local lastText = ""

-- The Wi-Fi reading and when it was taken, because taking it is expensive
-- enough to be worth keeping.
local wifiDetails = nil
local wifiFetchedAt = nil

-- Names of the machine's WLAN interfaces, which is how the primary interface
-- is recognised as a wireless one. Cheap enough to ask per panel build, and
-- asking beats caching: a USB Wi-Fi adapter appears without a reload.
local function isWireless(interfaceName)
  if interfaceName == nil then
    return false
  end

  for _, name in ipairs(hs.wifi.interfaces() or {}) do
    if name == interfaceName then
      return true
    end
  end

  return false
end

-- The Wi-Fi reading, taken at most every WIFI_REFRESH_SECONDS. Only asked for
-- while the panel is open, so an item nobody clicked never pays for it.
local function currentWifiDetails()
  local now = hs.timer.secondsSinceEpoch()

  if wifiFetchedAt == nil or now - wifiFetchedAt >= WIFI_REFRESH_SECONDS then
    wifiDetails = hs.wifi.interfaceDetails()
    wifiFetchedAt = now
  end

  return wifiDetails
end

-- The two rates as one stacked column: upload over download, each headed by
-- the arrow that names it.
local function columns()
  local resting = menubarRow.textColor()

  return {
    {
      reservedWidth = menubarRow.reservedWidth(RATE_WIDTH_TEMPLATE, nil, true),
      top = { icon = UPLOAD_ICON, text = formatRate(reading.uploadRate), color = resting },
      bottom = { icon = DOWNLOAD_ICON, text = formatRate(reading.downloadRate), color = resting },
    },
  }
end

-- Counters in, rates out, and one slot onto the history. Taking a rate
-- consumes the previous counters, so it happens exactly once per line.
local function applyLine(line)
  local counters = hs.json.decode(line)

  if counters == nil then
    return
  end

  reading.received = counters["in"]
  reading.sent = counters.out
  reading.interface = counters.interface
  reading.uploadRate, reading.downloadRate = tracker.rates(reading.received, reading.sent)

  lastText = barRow.paint(menu, columns())
end

local function startStream()
  if lineStream.isRunning(streamTask) then
    return
  end

  -- "watch" is this helper's own subcommand, not something lib knows.
  streamTask = lineStream.start(NETWORK_HELPER,
    { "watch", tostring(STREAM_INTERVAL_MILLISECONDS) }, applyLine)
end

local function stopStream()
  lineStream.stop(streamTask)

  streamTask = nil
end

-- The two rates spelled out, which is the same pair the row carries: the row
-- has the arrows and the figures and no room for a word, and this says which
-- arrow was which.
local function throughputSection()
  return {
    header = "Throughput",
    rows = {
      { label = "↓  Download", value = formatRate(reading.downloadRate) },
      { label = "↑  Upload", value = formatRate(reading.uploadRate) },
    },
  }
end

-- Signal strength gets the threshold treatment upside down: a Wi-Fi reading
-- gets worse as it falls, so the comparisons are the other way round from
-- every other reading on the bar.
local function signalColor(rssi, resting)
  if rssi == nil then
    return resting
  end

  if rssi <= CRITICAL_RSSI then
    return statPanel.CRITICAL_COLOR
  end

  if rssi <= WARN_RSSI then
    return statPanel.WARN_COLOR
  end

  return resting
end

-- The IPv4 address the interface is routing from, which is the one fact about
-- it worth as much as the rates.
local function interfaceAddress(interfaceName)
  if interfaceName == nil then
    return nil
  end

  local details = hs.network.interfaceDetails(interfaceName)
  local addresses = details ~= nil and details.IPv4 ~= nil and details.IPv4.Addresses or nil

  return addresses ~= nil and addresses[1] or nil
end

-- Signal as a share of the usable span rather than of the raw dBm figure,
-- which is negative and logarithmic and would fill the track backwards.
local function signalRow(rssi, noise, resting)
  local value = rssi .. " dBm"

  if noise ~= nil then
    value = value .. DETAIL_SEPARATOR .. noise .. " dBm noise"
  end

  local color = signalColor(rssi, resting)

  return {
    label = "Signal",
    value = value,
    color = color,
    fraction = statPanel.fraction(rssi - WORST_RSSI, BEST_RSSI - WORST_RSSI),
    gaugeColor = signalColor(rssi, statPanel.faded(resting, 0.75)),
  }
end

-- The negotiated rate and the channel it was negotiated on, which is what a
-- link that is fast enough on paper and slow in practice is explained by.
local function linkRow(details)
  local channel = details.wlanChannel
  local value = details.transmitRate ~= nil
    and string.format("%.0f Mbps", details.transmitRate) or PLACEHOLDER

  if channel ~= nil and channel.number ~= nil then
    value = value .. DETAIL_SEPARATOR .. "ch " .. channel.number
      .. " " .. (channel.band or "")
  end

  return { label = "Link", value = value }
end

-- What the machine is routing through: the interface, its address, and — when
-- that interface is a wireless one — the state of the radio behind it. A wired
-- machine gets neither row rather than two placeholders.
local function interfaceSection(resting)
  local interfaceName = reading.interface
  local rows = {
    {
      label = interfaceName or PLACEHOLDER,
      value = interfaceAddress(interfaceName) or NO_ADDRESS_TEXT,
    },
  }

  if isWireless(interfaceName) then
    local details = currentWifiDetails()

    if details ~= nil then
      if details.rssi ~= nil then
        rows[#rows + 1] = signalRow(details.rssi, details.noise, resting)
      end

      rows[#rows + 1] = linkRow(details)
    end
  end

  return { header = "Interface", rows = rows }
end

-- The counters the rates were taken from. Not "since boot": the kernel counter
-- they come from is 32-bit and starts over every 4G, so the totals are since
-- its last wrap.
local function totalsSection()
  return {
    header = "Totals",
    rows = {
      {
        label = "Received",
        value = formatBytes(reading.received),
      },
      {
        label = "Sent",
        value = formatBytes(reading.sent),
        detail = "since the 32-bit counter last wrapped at 4G",
      },
    },
  }
end

local function panelSections(resting)
  return {
    throughputSection(),
    interfaceSection(resting),
    totalsSection(),
  }
end

local panel = canvasPanel.new(menu, PANEL_REFRESH_SECONDS, panelSections)

-- Take the item out of the bar and kill the helper with it: hidden, the widget
-- costs nothing, not even the process.
local function hide()
  panel.hide()
  supervisorTimer:stop()
  stopStream()
  menu:removeFromMenuBar()

  canvasBanner.show({
    title = "Network hidden",
    subtitle = "hs -c 'require(\"network_stats\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back and start the stream again. The first rate lands one line after
-- that — two are needed for a delta — and until then the row shows the
-- placeholders it was built with rather than the rates it was hidden on.
local function show()
  menu:returnToMenuBar()
  startStream()
  supervisorTimer:start()
end

-- Restart the helper, which is the only "refresh" a streaming widget has: the
-- readings arrive on their own, and the useful manual action is bringing the
-- stream back after killing its process by hand.
local function restart()
  stopStream()
  startStream()
end

-- A click callback rather than a menu: the panel is drawn, and hs.menubar
-- honours one or the other.
menu:setClickCallback(panel.toggle)

supervisorTimer = hs.timer.new(SUPERVISOR_SECONDS, startStream)

-- Claim the menubar slot before the first line arrives, so the item is never a
-- zero-width gap on startup.
lastText = barRow.paint(menu, columns())
startStream()
supervisorTimer:start()

local widget = {
  refresh = restart,
  show = show,
  hide = hide,
  toggle = panel.toggle,
  -- Plain text of the current readout and of the panel behind it, for checking
  -- both from `hs -c` without squinting at the menubar.
  title = function() return lastText end,
  details = panel.text,
}

_G[INSTANCE_KEY] = widget

return widget
