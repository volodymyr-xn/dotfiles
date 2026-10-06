// Live state of every Claude Code profile on this machine, for the
// claude_stats menubar item in Hammerspoon: the sessions each profile has
// running, its plan limits, and the tokens it spent over the last 30 days.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the binary
// in ~/dotfiles/bin_native/macos/.
//
//   c-claude-stats-macos watch <claude> <pane-list> name=dir ...
//                       stream one JSON line per change until killed
//   c-claude-stats-macos once <claude> <pane-list> name=dir ...
//                       one sessions line and one usage line, then exit
//
// `<claude>` is the Claude Code executable, run as `claude agents --json`
// to learn why a session waits. `<pane-list>` is control_panel's
// c-tmux-ai-pane-list, the source of the tmux AI pane picker: only the
// sessions it lists are reported, so the panel and the picker agree. Each
// `name=dir` is one profile: the value its statusline exports as
// CLAUDE_PROFILE, and the CLAUDE_CONFIG_DIR it runs under.
//
// Two events, each printed only when its content changed:
//
//   {"event":"sessions", ...}  live sessions and limits
//   {"event":"usage", ...}     hourly token counts
//
// Nothing is read until the panel opens: the bar shows a fixed icon, so the
// panel is the only reader. While it is open, sessions are checked every 2s,
// the CLI is asked every 30s and transcripts are rescanned every minute. The
// process stays up in between so the usage scan keeps its offsets: only the
// first open after a start pays for reading 30 days of transcripts.
//
// Where each figure comes from, cheapest first:
//
//   sessions     <dir>/sessions/<pid>.json, which Claude Code rewrites on
//                every status change; a pid that is gone is dropped, and so
//                is one the tmux picker does not list
//   in tmux      <pane-list>, run only when a session pid turns up that has
//                no verdict yet (see TmuxAgentPids)
//   waiting      `claude agents --json` on the agents tick and on demand,
//                for why a session waits. Spawning the CLI costs ~130ms of
//                CPU per profile, far too much to pay every tick, and the
//                files above already cover everything else
//   limits       $TMPDIR/claude_rate_limits_<name>.json, the cache the
//                statusline (control_panel statuslines/command.lua) keeps
//   usage        <dir>/projects/**/*.jsonl, read incrementally: each file
//                is read once in full, then only from where the last scan
//                stopped. Files untouched for 30 days are never read
//
// The usage scan keeps its offsets in memory only, so every start reads the
// last 30 days again. That takes a few seconds once; persisting the state
// would add a cache format to keep in step with Claude Code's own.
//
// Commands on stdin, one per line: `live` starts reading (every source at
// once) and `idle` stops — the panel sends them as it opens and closes —
// `lock` and `unlock` rehearse the screen lock. EOF means Hammerspoon is
// gone, and so is this process.

import AppKit

// One Claude Code config directory and the name its caches are filed under.
struct Profile {
    let name: String
    let directory: URL

    var sessionsDirectory: URL { directory.appendingPathComponent("sessions") }
    var projectsDirectory: URL { directory.appendingPathComponent("projects") }
}

// Why nobody can see the bar. Tracked separately because they overlap and
// clear in any order: the screens wake before the lock is gone.
enum AwayReason {
    case locked
    case screensAsleep
    case screensaver
}

// MARK: - Report shapes

// One session as the panel lists it. `since` is when it entered its current
// state, in seconds.
struct SessionReport: Encodable, Equatable {
    let id: String
    let sessionId: String?
    let pid: Int32
    let kind: String
    let name: String
    let cwd: String
    let state: String
    let since: Double?
    let waitingFor: String?
    let model: String?
}

// One limit window: the share used and when it resets, in epoch seconds.
struct WindowReport: Encodable, Equatable {
    let pct: Double
    let resetsAt: Double
}

// Both limit windows and when the statusline last refreshed them.
struct LimitsReport: Encodable, Equatable {
    let fiveHour: WindowReport?
    let sevenDay: WindowReport?
    let updatedAt: Double?
}

// Everything the bar and the panel show for one profile, minus usage.
struct ProfileReport: Encodable, Equatable {
    let name: String
    let sessions: [SessionReport]
    let limits: LimitsReport?
}

// The `sessions` line. `event` sorts first under .sortedKeys, so Hammerspoon
// can tell the two lines apart without decoding the long one.
struct SessionsEvent: Encodable {
    let event = "sessions"
    let profiles: [ProfileReport]
}

// The `usage` line. `hours` rows are [hourEpoch, modelIndex, input, output,
// cacheWrite, cacheRead, responses], with the model name at `models[index]`.
// `sessionCounts` is distinct sessions per range and profile, plus "all" —
// a union, which the panel cannot rebuild from per-day counts.
struct UsageContent: Encodable, Equatable {
    let models: [String]
    let profiles: [String: [[Int]]]
    let sessionCounts: [String: [String: Int]]
}

// The `usage` line as printed: the content plus when the scan ran.
struct UsageEvent: Encodable {
    let event = "usage"
    let models: [String]
    let profiles: [String: [[Int]]]
    let scannedAt: Double
    let sessionCounts: [String: [String: Int]]

    // The printed line for `content`, stamped with when the scan ran.
    init(content: UsageContent, scannedAt: Double) {
        models = content.models
        profiles = content.profiles
        self.scannedAt = scannedAt
        sessionCounts = content.sessionCounts
    }
}

// MARK: - Small helpers

// JSON numbers arrive as NSNumber whatever their type; this reads either.
func number(_ value: Any?) -> Double? {
    (value as? NSNumber)?.doubleValue
}

// A JSON object out of raw bytes, or nil for anything else.
func jsonObject(_ data: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

// Whether `pid` is a live process. EPERM means it exists under another user.
func isAlive(_ pid: Int32) -> Bool {
    kill(pid, 0) == 0 || errno == EPERM
}

// Runs `executable` to completion and returns what it printed, or nil when it
// could not start. A child still running after `timeout` seconds is
// terminated, so a hung one cannot hold the caller's queue.
func runCapturingOutput(_ executable: String, arguments: [String], environment: [String: String],
                        timeout: Double) -> Data? {
    let process = Process()
    let output = Pipe()

    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.environment = environment
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        return nil
    }

    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
        if process.isRunning {
            process.terminate()
        }
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()

    process.waitUntilExit()

    return data
}

// MARK: - Limits

// Reads the per-profile rate-limit cache the statusline writes. Its path
// mirrors `cache_path` in statuslines/command.lua.
enum LimitsCache {
    // The cache file for one profile, under the per-user temp directory.
    static func url(for profile: Profile) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("claude_rate_limits_\(profile.name).json")
    }

    // Both windows and the newest `cached_at`, or nil before the statusline
    // has cached anything for this profile.
    static func read(for profile: Profile) -> LimitsReport? {
        guard let data = try? Data(contentsOf: url(for: profile)), let cache = jsonObject(data) else {
            return nil
        }

        let windows = cache["rate_limits"] as? [String: Any] ?? [:]
        let cachedAt = cache["cached_at"] as? [String: Any] ?? [:]
        let updatedAt = cachedAt.values.compactMap(number).max()

        return LimitsReport(fiveHour: window(windows["five_hour"]),
                            sevenDay: window(windows["seven_day"]),
                            updatedAt: updatedAt)
    }

    // One `{used_percentage, resets_at}` pair, or nil when either is missing.
    private static func window(_ value: Any?) -> WindowReport? {
        guard let fields = value as? [String: Any],
              let pct = number(fields["used_percentage"]),
              let resetsAt = number(fields["resets_at"]) else {
            return nil
        }

        return WindowReport(pct: pct, resetsAt: resetsAt)
    }
}

// MARK: - Sessions

// One entry of `claude agents --json`. Only what it adds to a session file
// is read: why the session with that pid waits.
struct AgentEntry {
    let pid: Int32?
    let waitingFor: String?

    // One entry out of the decoded JSON array.
    init(_ fields: [String: Any]) {
        pid = number(fields["pid"]).map { Int32($0) }
        waitingFor = fields["waitingFor"] as? String
    }
}

// Runs `claude agents --json` under one profile's config dir.
struct AgentsCommand {
    // Long enough for a cold start of the CLI, short enough that a hung one
    // does not hold the next refresh back.
    private static let timeoutSeconds = 10.0

    let executable: String

    // Every entry the CLI reported, or nil when it failed to run or print.
    func entries(for profile: Profile) -> [AgentEntry]? {
        var environment = ProcessInfo.processInfo.environment

        environment["CLAUDE_CONFIG_DIR"] = profile.directory.path

        guard let data = runCapturingOutput(executable, arguments: ["agents", "--json"],
                                            environment: environment, timeout: Self.timeoutSeconds),
              let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return nil
        }

        return list.map(AgentEntry.init)
    }
}

// Which sessions the tmux AI pane picker (control_panel's
// c-tmux-switch-ai-pane) lists, so the panel shows exactly those. Asks the
// picker's own list script rather than re-deriving which panes hold an
// agent, and only when a pid turns up that has no verdict yet: a process
// never moves into or out of a pane, so a yes holds for the pid's lifetime
// and the ~50ms script runs about once per new session, not every tick.
//
// Confined to the stream's work queue, like the rest of its state.
final class TmuxAgentPids {
    // A no is asked again after this long, because the script prints nothing
    // when tmux itself fails — a kept no would hide a live session for good.
    private static let negativeVerdictSeconds = 30.0
    // Long enough for a busy tmux server, short enough not to stall a tick.
    private static let timeoutSeconds = 5.0

    // Hammerspoon starts the helper with launchd's environment: no Homebrew
    // on PATH, so no tmux, and no locale, under which tmux swaps the tabs in
    // its -F output for underscores and the script matches no pane at all.
    private static let scriptEnvironment: [String: String] = {
        var environment = ProcessInfo.processInfo.environment

        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        environment["LANG"] = "en_US.UTF-8"

        return environment
    }()

    private let listScript: String
    private var listedPids = Set<Int32>()
    private var unlistedSince: [Int32: Date] = [:]

    // Nothing runs until the first `update`.
    init(listScript: String) {
        self.listScript = listScript
    }

    // Bring the verdicts up to date for the pids alive now. Pids that are
    // gone are forgotten, so a reused one is judged afresh.
    func update(livePids: Set<Int32>) {
        let now = Date()

        listedPids.formIntersection(livePids)
        unlistedSince = unlistedSince.filter { pid, judgedAt in
            livePids.contains(pid) && now.timeIntervalSince(judgedAt) < Self.negativeVerdictSeconds
        }

        let unjudged = livePids.subtracting(listedPids).subtracting(unlistedSince.keys)

        guard !unjudged.isEmpty, let scriptPids = pidsFromScript() else {
            return
        }

        for pid in unjudged {
            if scriptPids.contains(pid) {
                listedPids.insert(pid)
            } else {
                unlistedSince[pid] = now
            }
        }
    }

    // Whether the picker lists the session with this pid.
    func contains(_ pid: Int32) -> Bool {
        listedPids.contains(pid)
    }

    // The agent pids the list script printed, or nil when it did not run.
    private func pidsFromScript() -> Set<Int32>? {
        guard let data = runCapturingOutput(listScript, arguments: [], environment: Self.scriptEnvironment,
                                            timeout: Self.timeoutSeconds) else {
            return nil
        }

        // One line per pane: pane_id <TAB> agent_pid <TAB> what the picker shows.
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")

        return Set(lines.compactMap { line in
            line.split(separator: "\t", maxSplits: 2).dropFirst().first.flatMap { Int32($0) }
        })
    }
}

// Reads the per-pid session files of one profile and merges in what the
// last agents call added: the reason a session waits.
struct SessionsReader {
    // Sort order of the list: whoever needs you first, idle last.
    private static let stateRank = ["waiting": 0, "busy": 1, "idle": 2]

    // Every live session of `profile`, most urgent first.
    static func sessions(for profile: Profile, agents: [AgentEntry], models: [String: String]) -> [SessionReport] {
        let waitingByPid = Dictionary(agents.compactMap { entry in entry.pid.map { ($0, entry.waitingFor) } },
                                      uniquingKeysWith: { first, _ in first })

        return interactiveSessions(for: profile, waitingByPid: waitingByPid, models: models)
            .sorted(by: isMoreUrgent)
    }

    // One report per `<pid>.json` whose process is still running.
    private static func interactiveSessions(for profile: Profile, waitingByPid: [Int32: String?],
                                            models: [String: String]) -> [SessionReport] {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: profile.sessionsDirectory.path)) ?? []
        var reports: [SessionReport] = []

        for fileName in names where fileName.hasSuffix(".json") {
            let url = profile.sessionsDirectory.appendingPathComponent(fileName)

            guard let data = try? Data(contentsOf: url), let fields = jsonObject(data),
                  let pidNumber = number(fields["pid"]) else {
                continue
            }

            let pid = Int32(pidNumber)

            guard isAlive(pid) else {
                continue
            }

            let sessionId = fields["sessionId"] as? String
            let cwd = fields["cwd"] as? String ?? ""
            let statusSince = number(fields["statusUpdatedAt"]) ?? number(fields["updatedAt"])

            reports.append(SessionReport(id: sessionId ?? String(pid), sessionId: sessionId, pid: pid,
                                         kind: fields["kind"] as? String ?? "interactive",
                                         name: fields["name"] as? String ?? (cwd as NSString).lastPathComponent,
                                         cwd: cwd, state: fields["status"] as? String ?? "unknown",
                                         since: statusSince.map { $0 / 1000 },
                                         waitingFor: waitingByPid[pid] ?? nil,
                                         model: sessionId.flatMap { models[$0] }))
        }

        return reports
    }

    // Urgency first, then whichever changed state most recently.
    private static func isMoreUrgent(_ left: SessionReport, _ right: SessionReport) -> Bool {
        let leftRank = stateRank[left.state] ?? 3
        let rightRank = stateRank[right.state] ?? 3

        if leftRank != rightRank {
            return leftRank < rightRank
        }

        return (left.since ?? 0) > (right.since ?? 0)
    }
}

// MARK: - Usage

// Token counts for one hour, one model and one profile.
struct TokenCounts: Equatable {
    var input = 0
    var output = 0
    var cacheWrite = 0
    var cacheRead = 0
    var responses = 0

    var total: Int { input + output + cacheWrite + cacheRead }

    // Adds `other` field by field.
    mutating func add(_ other: TokenCounts) {
        input += other.input
        output += other.output
        cacheWrite += other.cacheWrite
        cacheRead += other.cacheRead
        responses += other.responses
    }

    // What `newer` added on top of `self`, never negative.
    func increase(to newer: TokenCounts) -> TokenCounts {
        TokenCounts(input: max(0, newer.input - input), output: max(0, newer.output - output),
                    cacheWrite: max(0, newer.cacheWrite - cacheWrite),
                    cacheRead: max(0, newer.cacheRead - cacheRead), responses: 0)
    }
}

// Sums transcript usage per hour, model and profile, reading only what was
// appended since the previous scan. The approach is ClaudeBar's
// (github.com/LHner1/claude-bar, UsageScanner.swift), widened to several
// config dirs and bounded to the last 30 days.
final class UsageScanner {
    // A message already counted, so a rewrite of the same message (Claude
    // Code writes one response over several lines) only adds its increase.
    private struct CountedMessage {
        let profile: Int
        let hour: Int
        let model: Int
        var counts: TokenCounts
    }

    // The newest model a top-level transcript used, and when.
    private struct SessionModel {
        let model: String
        let at: Double
    }

    private static let windowDays = 30
    // How long a counted message is remembered. The lines of one response
    // land seconds apart, and offsets keep old lines from being read twice,
    // so only a transcript rewritten from the start could double-count
    // anything older — and that has not been seen to happen. Keeping every
    // message for 30 days was most of the helper's resident memory.
    private static let dedupHorizonSeconds = 2.0 * 86400
    private static let chunkBytes = 8 << 20
    private static let idleBufferBytes = 64 << 10
    private static let newline = UInt8(ascii: "\n")
    // Unescaped quotes only occur in JSON structure, never inside a string,
    // so this matches the key and value rather than transcript text.
    private static let assistantMarker = Array("\"type\":\"assistant\"".utf8)
    private static let headWindowBytes = 512
    private static let tailWindowBytes = 4096
    // The message's content array, cut out before parsing: it is nearly
    // all of a line's bytes and none of what is counted. It opens a couple
    // of hundred bytes in and closes right before `container` (`stop_reason`
    // on older transcripts), about a kilobyte before the end; the windows
    // leave generous room for both.
    private static let contentOpen = Array("\"content\":[".utf8)
    private static let contentCloses = [Array("],\"container\":".utf8), Array("],\"stop_reason\":".utf8)]
    private static let contentOpenWindowBytes = 8192
    private static let contentCloseWindowBytes = 32768

    private let profiles: [Profile]
    private var offsets: [String: UInt64] = [:]
    private var counted: [String: CountedMessage] = [:]
    private var hourly: [[Int: [Int: TokenCounts]]]
    private var sessionsByDay: [[Int: Set<String>]]
    private var models: [String] = []
    private var modelIndex: [String: Int] = [:]
    private var sessionModels: [String: SessionModel] = [:]
    private var dayStartByHour: [Int: Int] = [:]
    private var readBuffer: UnsafeMutableRawPointer
    private var readCapacity = UsageScanner.idleBufferBytes
    private let fractionalDates: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let wholeSecondDates = ISO8601DateFormatter()

    // Empty totals for `profiles`; nothing is read until `scan`.
    init(profiles: [Profile]) {
        self.profiles = profiles
        hourly = Array(repeating: [:], count: profiles.count)
        sessionsByDay = Array(repeating: [:], count: profiles.count)
        readBuffer = malloc(Self.idleBufferBytes)!
    }

    // The read buffer is malloc-owned, so it is freed by hand.
    deinit {
        free(readBuffer)
    }

    // The newest model each session's own transcript used, by session id.
    var latestModels: [String: String] {
        sessionModels.mapValues(\.model)
    }

    // Read whatever every profile's transcripts gained since the last call,
    // then hand the scan's buffers back to the system: without it the helper
    // sits at the first scan's high-water mark for good. The read buffer is
    // full size only while a scan runs.
    func scan() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Double(Self.windowDays + 1) * 86400)

        resizeReadBuffer(to: Self.chunkBytes)

        for (index, profile) in profiles.enumerated() {
            scanProfile(index, profile, cutoff: cutoff)
        }

        prune(before: Int(cutoff.timeIntervalSince1970),
              countedBefore: Int(now.timeIntervalSince1970 - Self.dedupHorizonSeconds))
        resizeReadBuffer(to: Self.idleBufferBytes)
        malloc_zone_pressure_relief(nil, 0)
    }

    // What the `usage` line carries, built from the current totals.
    func content() -> UsageContent {
        var rowsByProfile: [String: [[Int]]] = [:]

        for (index, profile) in profiles.enumerated() {
            var rows: [[Int]] = []

            for (hour, byModel) in hourly[index] {
                for (model, counts) in byModel {
                    rows.append([hour, model, counts.input, counts.output, counts.cacheWrite,
                                 counts.cacheRead, counts.responses])
                }
            }

            rowsByProfile[profile.name] = rows.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) }
        }

        return UsageContent(models: models, profiles: rowsByProfile, sessionCounts: sessionCounts())
    }

    // Distinct sessions with usage today, over 7 days and over 30 days, per
    // profile and across all of them. Ranges end today and count whole days.
    private func sessionCounts() -> [String: [String: Int]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let ranges = [("today", 0), ("week", 6), ("month", 29)]
        var result: [String: [String: Int]] = [:]

        for (rangeName, daysBack) in ranges {
            let start = Int(calendar.date(byAdding: .day, value: -daysBack, to: today)!.timeIntervalSince1970)
            var everyProfile = Set<String>()
            var counts: [String: Int] = [:]

            for (index, profile) in profiles.enumerated() {
                var ids = Set<String>()

                for (day, sessions) in sessionsByDay[index] where day >= start {
                    ids.formUnion(sessions)
                }

                counts[profile.name] = ids.count
                everyProfile.formUnion(ids)
            }

            counts["all"] = everyProfile.count
            result[rangeName] = counts
        }

        return result
    }

    // Every .jsonl under one profile's projects dir, read from its offset.
    private func scanProfile(_ index: Int, _ profile: Profile, cutoff: Date) {
        let projects = profile.projectsDirectory.standardizedFileURL
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]

        guard let enumerator = FileManager.default.enumerator(at: projects, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles]) else {
            return
        }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize.map(UInt64.init) else {
                continue
            }

            let path = url.path
            var offset = offsets[path]

            // Older than the window and never read: skip its history, but
            // read anything a resumed session appends from here on.
            if offset == nil, let modified = values.contentModificationDate, modified < cutoff {
                offsets[path] = size
                continue
            }

            if let known = offset, size < known {
                offset = 0
            }

            let start = offset ?? 0

            guard size > start else {
                continue
            }

            // A session's own transcript sits at projects/<project>/<id>.jsonl;
            // subagent transcripts nest deeper and must not set its model.
            let isSessionTranscript = url.deletingLastPathComponent().deletingLastPathComponent()
                .standardizedFileURL == projects
            let transcriptSession = isSessionTranscript ? url.deletingPathExtension().lastPathComponent : nil

            offsets[path] = read(url, from: start, profile: index, transcriptSession: transcriptSession)
        }
    }

    // Reads from `offset` up to the last complete line and returns the
    // offset to resume from. One buffer serves every file and every scan:
    // a fresh chunk per read, plus a copy of every matching line, left the
    // helper holding a first scan's worth of freed pages for good.
    private func read(_ url: URL, from offset: UInt64, profile: Int, transcriptSession: String?) -> UInt64 {
        let descriptor = open(url.path, O_RDONLY)

        guard descriptor >= 0 else {
            return offset
        }

        defer { close(descriptor) }

        var position = offset
        var filled = 0

        while true {
            // A single line longer than the buffer: grow until it fits.
            if filled == readCapacity {
                resizeReadBuffer(to: readCapacity * 2)
            }

            let count = pread(descriptor, readBuffer + filled, readCapacity - filled,
                              off_t(position) + off_t(filled))

            guard count > 0 else {
                break
            }

            filled += count

            // JSONSerialization autoreleases every object it builds.
            let consumed = autoreleasepool {
                scanLines(length: filled, profile: profile, transcriptSession: transcriptSession)
            }

            if consumed > 0 {
                memmove(readBuffer, readBuffer + consumed, filled - consumed)
                filled -= consumed
                position += UInt64(consumed)
            }
        }

        return position
    }

    // Swap the read buffer for one of `capacity` bytes, keeping its content.
    private func resizeReadBuffer(to capacity: Int) {
        guard let resized = realloc(readBuffer, capacity) else {
            return
        }

        readBuffer = resized
        readCapacity = capacity
    }

    // Counts every assistant line among the complete lines at the front of
    // the read buffer and returns how many bytes they span, newline included.
    private func scanLines(length: Int, profile: Int, transcriptSession: String?) -> Int {
        var start = 0

        while start < length {
            let lineStart = UnsafeRawPointer(readBuffer + start)

            guard let newline = memchr(lineStart, Int32(Self.newline), length - start) else {
                break
            }

            let lineLength = UnsafeRawPointer(newline) - lineStart

            if lineLength > 0, Self.contains(Self.assistantMarker, inEndsOf: lineStart, length: lineLength) {
                process(lineStart, length: lineLength, profile: profile, transcriptSession: transcriptSession)
            }

            start += lineLength + 1
        }

        return start
    }

    // Whether `needle` occurs in the head or the tail window of a line.
    //
    // Only the ends of a line are searched. `"type":"assistant"` sits either
    // in the first few hundred bytes or among the trailing keys after the
    // message, and the content in between is nearly all of the bytes. JSON
    // is so dense in `"` — the needle's first byte — that a whole-line
    // search was most of a first scan. Checked against 47k assistant lines
    // of real transcripts with no miss.
    private static func contains(_ needle: [UInt8], inEndsOf line: UnsafeRawPointer, length: Int) -> Bool {
        let headLength = min(length, headWindowBytes)

        if firstOffset(of: needle, in: line, length: headLength) != nil {
            return true
        }

        guard length > headLength else {
            return false
        }

        let tailLength = min(length - headLength, tailWindowBytes)

        return firstOffset(of: needle, in: line + (length - tailLength), length: tailLength) != nil
    }

    // Offset of the first `needle` within `length` bytes at `bytes`. memmem
    // rather than Data's own searching, which is a generic Swift loop.
    private static func firstOffset(of needle: [UInt8], in bytes: UnsafeRawPointer, length: Int) -> Int? {
        needle.withUnsafeBytes { pattern in
            memmem(bytes, length, pattern.baseAddress, pattern.count).map { UnsafeRawPointer($0) - bytes }
        }
    }

    // Offset of the last `needle` within `length` bytes at `bytes`.
    private static func lastOffset(of needle: [UInt8], in bytes: UnsafeRawPointer, length: Int) -> Int? {
        var found: Int?
        var searchFrom = 0

        while searchFrom < length, let match = firstOffset(of: needle, in: bytes + searchFrom, length: length - searchFrom) {
            found = searchFrom + match
            searchFrom += match + 1
        }

        return found
    }

    // The line with its message content emptied, assembled straight out of
    // the read buffer so the content is never copied. Nil when the content
    // array is not where it is expected; the caller then parses it whole.
    private static func withoutContent(_ line: UnsafeRawPointer, length: Int) -> Data? {
        guard let open = firstOffset(of: contentOpen, in: line, length: min(length, contentOpenWindowBytes)) else {
            return nil
        }

        let contentStart = open + contentOpen.count
        let closeWindow = min(length - contentStart, contentCloseWindowBytes)
        let windowStart = length - closeWindow

        for close in contentCloses {
            guard let match = lastOffset(of: close, in: line + windowStart, length: closeWindow) else {
                continue
            }

            let contentEnd = windowStart + match
            var reduced = Data(bytes: line, count: contentStart)

            reduced.append(line.assumingMemoryBound(to: UInt8.self) + contentEnd, count: length - contentEnd)

            return reduced
        }

        return nil
    }

    // Whole epoch seconds of a UTC timestamp in the one shape Claude Code
    // writes, `2026-10-04T13:55:10.622Z`, or nil for any other. The
    // formatters stay as the fallback; they go through ICU and were a tenth
    // of a first scan on their own.
    private static func utcEpoch(_ text: String) -> Double? {
        let bytes = Array(text.utf8)

        guard bytes.count >= 20, bytes[4] == UInt8(ascii: "-"), bytes[10] == UInt8(ascii: "T"),
              bytes.last == UInt8(ascii: "Z") else {
            return nil
        }

        // The decimal value of `count` ASCII digits starting at `start`.
        func digits(_ start: Int, _ count: Int) -> Int32? {
            var value: Int32 = 0

            for byte in bytes[start..<(start + count)] {
                guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
                    return nil
                }

                value = value * 10 + Int32(byte - UInt8(ascii: "0"))
            }

            return value
        }

        guard let year = digits(0, 4), let month = digits(5, 2), let day = digits(8, 2),
              let hour = digits(11, 2), let minute = digits(14, 2), let second = digits(17, 2) else {
            return nil
        }

        var time = tm()
        time.tm_year = year - 1900
        time.tm_mon = month - 1
        time.tm_mday = day
        time.tm_hour = hour
        time.tm_min = minute
        time.tm_sec = second

        return Double(timegm(&time))
    }

    // Counts one assistant line, once per message id and request. Parses the
    // line without its content, and the whole line only if that fails.
    private func process(_ line: UnsafeRawPointer, length: Int, profile: Int, transcriptSession: String?) {
        guard let fields = Self.withoutContent(line, length: length).flatMap(jsonObject)
                ?? jsonObject(Data(bytes: line, count: length)),
              fields["type"] as? String == "assistant",
              let message = fields["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String, model != "<synthetic>",
              let timestamp = fields["timestamp"] as? String,
              let epoch = Self.utcEpoch(timestamp)
                ?? (fractionalDates.date(from: timestamp) ?? wholeSecondDates.date(from: timestamp))?
                    .timeIntervalSince1970 else {
            return
        }

        let hour = Int(epoch) / 3600 * 3600
        let counts = TokenCounts(input: Int(number(usage["input_tokens"]) ?? 0),
                                 output: Int(number(usage["output_tokens"]) ?? 0),
                                 cacheWrite: Int(number(usage["cache_creation_input_tokens"]) ?? 0),
                                 cacheRead: Int(number(usage["cache_read_input_tokens"]) ?? 0),
                                 responses: 1)
        let key = "\(message["id"] as? String ?? UUID().uuidString):\(fields["requestId"] as? String ?? "")"

        if let session = transcriptSession, epoch >= (sessionModels[session]?.at ?? 0) {
            sessionModels[session] = SessionModel(model: model, at: epoch)
        }

        if let sessionId = fields["sessionId"] as? String {
            sessionsByDay[profile][dayStart(forHour: hour), default: []].insert(sessionId)
        }

        if var previous = counted[key] {
            let increase = previous.counts.increase(to: counts)

            guard increase.total > 0 else {
                return
            }

            hourly[previous.profile][previous.hour, default: [:]][previous.model, default: TokenCounts()]
                .add(increase)
            previous.counts.add(increase)
            counted[key] = previous

            return
        }

        let modelId = index(of: model)

        hourly[profile][hour, default: [:]][modelId, default: TokenCounts()].add(counts)
        counted[key] = CountedMessage(profile: profile, hour: hour, model: modelId, counts: counts)
    }

    // Local midnight of the day an hour falls in, cached per hour.
    private func dayStart(forHour hour: Int) -> Int {
        if let known = dayStartByHour[hour] {
            return known
        }

        let start = Int(Calendar.current.startOfDay(for: Date(timeIntervalSince1970: Double(hour)))
            .timeIntervalSince1970)

        dayStartByHour[hour] = start

        return start
    }

    // Position of `model` in the shared model list, adding it on first sight.
    private func index(of model: String) -> Int {
        if let known = modelIndex[model] {
            return known
        }

        models.append(model)
        modelIndex[model] = models.count - 1

        return models.count - 1
    }

    // Forget hours, days and models that slid out of the window, and
    // messages older than the dedup horizon.
    private func prune(before cutoff: Int, countedBefore countedCutoff: Int) {
        for index in profiles.indices {
            hourly[index] = hourly[index].filter { $0.key >= cutoff }
            sessionsByDay[index] = sessionsByDay[index].filter { $0.key >= cutoff }
        }

        counted = counted.filter { $0.value.hour >= countedCutoff }
        dayStartByHour = dayStartByHour.filter { $0.key >= cutoff }
        sessionModels = sessionModels.filter { $0.value.at >= Double(cutoff) }
    }
}

// MARK: - Stream

// The `watch` subcommand: while the panel is open, ticks every source on
// its own cadence and prints a line when what it found changed; it also
// pauses while nobody can see the screen.
final class ClaudeStatsStream {
    // How often each source is read while the panel is open.
    private static let sessionsSeconds = 2.0
    private static let agentsSeconds = 30.0
    private static let usageSeconds = 60.0
    // A usage line is printed at least this often even when nothing changed,
    // so the panel's "scanned at" stays honest.
    private static let usageHeartbeatSeconds = 300.0
    // How soon after a session starts waiting the agents call may run again
    // to learn why. Several sessions flipping at once cost one call.
    private static let waitingRefreshSeconds = 5.0

    // Screen lock, unlock and screensaver arrive as distributed
    // notifications; there is no NSWorkspace equivalent.
    private static let awayNotifications: [(name: String, reason: AwayReason, away: Bool)] = [
        ("com.apple.screenIsLocked", .locked, true),
        ("com.apple.screenIsUnlocked", .locked, false),
        ("com.apple.screensaver.didstart", .screensaver, true),
        ("com.apple.screensaver.didstop", .screensaver, false),
    ]

    private let profiles: [Profile]
    private let agentsCommand: AgentsCommand
    private let tmuxAgents: TmuxAgentPids
    private let scanner: UsageScanner
    private let work = DispatchQueue(label: "c-claude-stats.work", qos: .utility)
    private let agentsWork = DispatchQueue(label: "c-claude-stats.agents", qos: .utility)
    private let usageWork = DispatchQueue(label: "c-claude-stats.usage", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    // Confined to `work`.
    private var agentsByProfile: [String: [AgentEntry]] = [:]
    private var models: [String: String] = [:]
    private var lastSessionsLine: Data?
    private var lastUsageContent: UsageContent?
    private var lastUsagePrint = Date.distantPast
    private var waitingPids = Set<Int32>()
    private var lastWaitingRefresh = Date.distantPast
    private var agentsRunning = false
    private var usageRunning = false

    // Confined to the main queue.
    private var away = Set<AwayReason>()
    // Whether the panel is open. Nothing is read while it is closed.
    private var live = false
    private var timers: [DispatchSourceTimer] = []

    // Wires the sources up; nothing ticks until the panel goes live.
    init(profiles: [Profile], claudeExecutable: String, paneListScript: String) {
        self.profiles = profiles
        agentsCommand = AgentsCommand(executable: claudeExecutable)
        tmuxAgents = TmuxAgentPids(listScript: paneListScript)
        scanner = UsageScanner(profiles: profiles)
    }

    // Begin: watch for the bar going out of sight and for stdin, then tick.
    func start() {
        observeAway()
        watchStandardInput()
        resume()
    }

    // Run every source once, synchronously, and print both lines: the
    // `once` subcommand.
    func runOnce() {
        work.sync {
            refreshAgentsNow()
            scanUsageNow(forcePrint: true)
            tickSessions()
        }
    }

    // MARK: Ticks

    // Re-read session files and limit caches, keep the sessions the tmux
    // picker lists, and print when anything changed.
    private func tickSessions() {
        let sessionsByProfile = profiles.map { profile in
            SessionsReader.sessions(for: profile, agents: agentsByProfile[profile.name] ?? [], models: models)
        }

        tmuxAgents.update(livePids: Set(sessionsByProfile.joined().map(\.pid)))

        let reports = zip(profiles, sessionsByProfile).map { profile, sessions in
            ProfileReport(name: profile.name, sessions: sessions.filter { tmuxAgents.contains($0.pid) },
                          limits: LimitsCache.read(for: profile))
        }

        noticeNewlyWaiting(reports)

        guard let line = try? encoder.encode(SessionsEvent(profiles: reports)), line != lastSessionsLine else {
            return
        }

        lastSessionsLine = line
        emit(line)
    }

    // A session that just started waiting gets its reason from the CLI.
    private func noticeNewlyWaiting(_ reports: [ProfileReport]) {
        let waiting = Set(reports.flatMap(\.sessions).filter { $0.state == "waiting" }.map(\.pid))
        let appeared = !waiting.subtracting(waitingPids).isEmpty

        waitingPids = waiting

        if appeared, Date().timeIntervalSince(lastWaitingRefresh) >= Self.waitingRefreshSeconds {
            lastWaitingRefresh = Date()
            refreshAgents()
        }
    }

    // Ask every profile's CLI for its agents off the work queue, then merge.
    private func refreshAgents() {
        guard !agentsRunning else {
            return
        }

        agentsRunning = true

        agentsWork.async { [self] in
            let fetched = profiles.map { profile in (profile.name, agentsCommand.entries(for: profile)) }

            work.async { [self] in
                agentsRunning = false
                mergeAgents(fetched)
                tickSessions()
            }
        }
    }

    // The synchronous variant for `once`.
    private func refreshAgentsNow() {
        mergeAgents(profiles.map { profile in (profile.name, agentsCommand.entries(for: profile)) })
    }

    // Keep the last good answer for a profile whose CLI call failed.
    private func mergeAgents(_ fetched: [(String, [AgentEntry]?)]) {
        for (name, entries) in fetched {
            if let entries {
                agentsByProfile[name] = entries
            }
        }
    }

    // Rescan transcripts off the work queue, then print when usage changed.
    private func scanUsage() {
        guard !usageRunning else {
            return
        }

        usageRunning = true

        usageWork.async { [self] in
            scanner.scan()

            let content = scanner.content()
            let latestModels = scanner.latestModels

            work.async { [self] in
                usageRunning = false
                models = latestModels
                printUsage(content, force: false)
                tickSessions()
            }
        }
    }

    // The synchronous variant for `once`.
    private func scanUsageNow(forcePrint: Bool) {
        scanner.scan()
        models = scanner.latestModels
        printUsage(scanner.content(), force: forcePrint)
    }

    // Print the usage line when it changed or the heartbeat is due.
    private func printUsage(_ content: UsageContent, force: Bool) {
        let now = Date()
        let due = now.timeIntervalSince(lastUsagePrint) >= Self.usageHeartbeatSeconds

        guard force || due || content != lastUsageContent,
              let line = try? encoder.encode(UsageEvent(content: content, scannedAt: now.timeIntervalSince1970)) else {
            return
        }

        lastUsageContent = content
        lastUsagePrint = now
        emit(line)
    }

    // One JSON object per line, written straight to the descriptor so no
    // buffer holds it back; a closed pipe raises SIGPIPE and ends the
    // process, which is what should happen when Hammerspoon is gone.
    private func emit(_ line: Data) {
        FileHandle.standardOutput.write(line + Data("\n".utf8))
    }

    // MARK: Timers and visibility

    // Start one repeating timer per source, each firing once straight away —
    // only while the panel is open.
    private func resume() {
        guard timers.isEmpty, live else {
            return
        }

        timers = [
            repeating(every: Self.sessionsSeconds) { [self] in tickSessions() },
            repeating(every: Self.agentsSeconds) { [self] in refreshAgents() },
            repeating(every: Self.usageSeconds) { [self] in scanUsage() },
        ]
    }

    // The panel opened: read every source now, then keep ticking.
    private func goLive() {
        live = true

        if away.isEmpty {
            resume()
        }
    }

    // The panel closed: stop reading until it opens again.
    private func goIdle() {
        live = false
        pause()
    }

    // Stop every timer; scans already running finish on their own.
    private func pause() {
        timers.forEach { $0.cancel() }
        timers = []
    }

    // A timer on the work queue that runs `action` now and every `seconds`.
    private func repeating(every seconds: Double, _ action: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: work)

        timer.schedule(deadline: .now(), repeating: seconds, leeway: .milliseconds(250))
        timer.setEventHandler(handler: action)
        timer.resume()

        return timer
    }

    // Record one reason for being out of sight, then pause or resume.
    private func setAway(_ reason: AwayReason, _ isAway: Bool) {
        if isAway {
            away.insert(reason)
        } else {
            away.remove(reason)
        }

        if away.isEmpty {
            resume()
        } else {
            pause()
        }
    }

    // Stop ticking while the screens are locked, asleep, or behind the
    // screensaver.
    private func observeAway() {
        let workspace = NSWorkspace.shared.notificationCenter

        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil,
                              queue: .main) { [weak self] _ in
            self?.setAway(.screensAsleep, true)
        }

        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil,
                              queue: .main) { [weak self] _ in
            self?.setAway(.screensAsleep, false)
        }

        for entry in Self.awayNotifications {
            DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name(entry.name),
                                                                object: nil, queue: .main) { [weak self] _ in
                self?.setAway(entry.reason, entry.away)
            }
        }
    }

    // Commands from Hammerspoon, one per line. Only watched when stdin is a
    // pipe — a terminal or /dev/null would read as EOF at once.
    private func watchStandardInput() {
        var status = stat()

        guard fstat(STDIN_FILENO, &status) == 0, (status.st_mode & S_IFMT) == S_IFIFO else {
            return
        }

        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            DispatchQueue.main.async {
                guard !data.isEmpty else {
                    exit(0)
                }

                self?.handleCommands(String(decoding: data, as: UTF8.self))
            }
        }
    }

    // Apply each command line Hammerspoon wrote.
    private func handleCommands(_ text: String) {
        for line in text.split(separator: "\n") {
            switch line.trimmingCharacters(in: .whitespaces) {
            case "live":
                goLive()
            case "idle":
                goIdle()
            case "lock":
                setAway(.locked, true)
            case "unlock":
                setAway(.locked, false)
            default:
                continue
            }
        }
    }
}

// MARK: - Entry point

// Parses the command line and runs the chosen subcommand.
enum ClaudeStatsCommand {
    private static let usage = "usage: c-claude-stats-macos watch|once <claude> <pane-list> name=dir ..."

    // `name=dir` pairs into profiles, `~` expanded.
    static func profiles(_ arguments: ArraySlice<String>) -> [Profile] {
        arguments.compactMap { argument in
            guard let separator = argument.firstIndex(of: "=") else {
                return nil
            }

            let name = String(argument[..<separator])
            let path = (String(argument[argument.index(after: separator)...]) as NSString).expandingTildeInPath

            return Profile(name: name, directory: URL(fileURLWithPath: path))
        }
    }

    // Run `watch` until killed or `once` and exit; 64 for a bad command line.
    static func main() {
        let arguments = CommandLine.arguments

        guard arguments.count >= 5 else {
            FileHandle.standardError.write(Data((usage + "\n").utf8))
            exit(64)
        }

        let stream = ClaudeStatsStream(profiles: profiles(arguments.dropFirst(4)), claudeExecutable: arguments[2],
                                       paneListScript: arguments[3])

        switch arguments[1] {
        case "watch":
            stream.start()
            RunLoop.main.run()
        case "once":
            stream.runOnce()
        default:
            FileHandle.standardError.write(Data((usage + "\n").utf8))
            exit(64)
        }
    }
}

ClaudeStatsCommand.main()
