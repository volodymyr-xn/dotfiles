-- Menubar readout of what the machine is moving over its network: upload over
-- download for the interface the default route currently uses, refreshed on
-- every line of the shared stats stream, with the interface's own details
-- behind a click.
--
-- Its own item rather than a column of the sensors row, because throughput is
-- the spikiest reading on the bar and wants a column wide enough for "999
-- MB/s" without pushing the sensor figures around. It used to want a cadence
-- of its own too — a line a second from a helper of its own — but that cost a
-- third wake-up every two seconds for a figure that reads just as well over
-- two; it now repaints on the same line, and in the same commit, as
-- system_stats.
--
-- The item itself is drawn by c-system-sensors-macos, not here (see
-- native_modules/macos/c-system-sensors-macos.swift, NetworkRow): the two
-- rates stacked in the height of the bar the same way the sensor columns are,
-- the arrows naming them. The helper reads the primary interface's AF_LINK
-- counters, turns them into rates, and repaints the item on its own timer;
-- this file gets the readings over stats_stream and draws only the panel.
--
-- Build the helper once with `dotfiles_setup/build_native_modules.sh`; until
-- then this shows placeholders rather than disappearing, so a missing binary
-- is visible.
--
-- Clicking the item opens a panel with everything the row has no width for:
-- the two rates spelled out, the interface's address, its Wi-Fi signal when it
-- has one, and the totals the rates were taken from. The helper reports the
-- click with the item's frame, which is where the panel hangs.
-- The panel is a canvas rather than a menu, which is what buys it a refresh
-- while it is open; canvas_panel owns the surface, the placement and the
-- dismissal, and process_stats draws its own the same way.
--
-- There is no hide item in the panel: `hs -c 'require("network_stats").hide()'`
-- still works, and `show()` or a config reload brings the widget back.

-- One widget per Hammerspoon instance. modules/ is on package.path, so the
-- file is reachable as both "network_stats" and "modules.network_stats" — two
-- package.loaded entries, and without this guard the second require runs the
-- body again and builds a second panel.
local INSTANCE_KEY = "networkStatsWidget"

if _G[INSTANCE_KEY] ~= nil then
  return _G[INSTANCE_KEY]
end

local canvasBanner = require("canvas_banner")
local canvasPanel = require("canvas_panel")
local statFormat = require("stat_format")
local statPanel = require("stat_panel")
local statsStream = require("stats_stream")

local formatBytes = statFormat.bytes
local formatRate = statFormat.rate
local PLACEHOLDER = statFormat.PLACEHOLDER

-- While the panel is open. Matched to the stream, so every repaint shows a
-- new reading rather than the same one twice.
local PANEL_REFRESH_SECONDS = statsStream.INTERVAL_SECONDS

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

-- The latest counters and the rates taken from them. One table reused rather
-- than replaced, so the panel always reads the reading of the moment.
local reading = {}

-- Plain-text mirror of what the helper last painted, for the `title` accessor.
local lastText = ""

-- Where the item sat when it was last clicked, in Hammerspoon's screen
-- coordinates. The panel hangs from it and a click inside it closes the
-- panel; nil until the first click, which is also the first open.
local itemFrame = nil

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

-- Keep the tick's figures for the panel and the `title` accessor. The rates
-- arrive already taken: the helper holds the baseline, and drops it itself
-- after a pause.
local function applyReadings(event)
  reading.received = event.net_in
  reading.sent = event.net_out
  reading.interface = event.net_interface
  reading.uploadRate = event.up_rate
  reading.downloadRate = event.down_rate

  lastText = event.network_text or ""
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

-- An empty frame before the first click, which containsPoint never matches.
local function anchorFrame()
  return itemFrame or { x = 0, y = 0, w = 0, h = 0 }
end

local panel = canvasPanel.new(anchorFrame, PANEL_REFRESH_SECONDS, panelSections)

-- The item was clicked: remember where it is, then open or close the panel.
local function handleClick(event)
  itemFrame = event.frame
  panel.toggle()
end

local subscriber = { readings = applyReadings, click = handleClick }

-- Take the item out of the bar: the helper restarts without it, or stops
-- when no other widget is left. Hidden, the widget costs nothing.
local function hide()
  panel.hide()
  statsStream.unsubscribe("network")

  canvasBanner.show({
    title = "Network hidden",
    subtitle = "hs -c 'require(\"network_stats\").show()'",
    state = "off",
    icon = HIDDEN_ICON,
  })
end

-- Put it back. The first rate lands one tick after that — two readings are
-- needed for a delta — and until then the row shows placeholders.
local function show()
  statsStream.subscribe("network", subscriber)
end

statsStream.subscribe("network", subscriber)

local widget = {
  refresh = statsStream.restart,
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
