// Live state of every Claude Code profile on this machine, for the
// claude_stats menubar item in Hammerspoon: the sessions each profile has
// running and its plan limits.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the binary
// in ~/dotfiles/bin_native/macos/.
//
//   c-claude-stats-macos watch <claude> <pane-list> name=dir ...
//                       stream one JSON line per change until killed
//   c-claude-stats-macos once <claude> <pane-list> name=dir ...
//                       one sessions line, then exit
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
//   {"event":"bar", ...}       idle, busy, waiting, busyWaiting or away,
//                              for the bar icon
//   {"event":"sessions", ...}  live sessions and limits
//
// The bar state is all that is read while the panel is closed, and only on
// events: FSEvents on every profile's sessions/ directory, and an exit watch
// on each busy or waiting pid, because a session that dies mid-turn leaves
// its file behind unchanged. While nobody can see the screen the bar is
// `away` and nothing is read at all. Everything else waits for the panel.
// While it is open, sessions are checked every 2s and the CLI is asked every
// 30s.
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
//
// Commands on stdin, one per line: `live` starts reading (every source at
// once) and `idle` stops — the panel sends them as it opens and closes —
// `lock` and `unlock` rehearse the screen lock. EOF means Hammerspoon is
// gone, and so is this process.

import AppKit
import CoreServices

// One Claude Code config directory and the name its caches are filed under.
struct Profile {
    let name: String
    let directory: URL

    var sessionsDirectory: URL { directory.appendingPathComponent("sessions") }
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

// Everything the panel shows for one profile.
struct ProfileReport: Encodable, Equatable {
    let name: String
    let sessions: [SessionReport]
    let limits: LimitsReport?
}

// What the bar icon shows. `away` means nobody can see the screen, so the
// icon has no reason to animate.
enum BarState: String, Encodable {
    case idle
    case busy
    case waiting
    case busyWaiting
    case away

    // The session statuses that keep the bar off idle.
    static let workingStatuses: Set<String> = [BarState.busy.rawValue, BarState.waiting.rawValue]

    // The most urgent of session `statuses`: one at work alongside one that
    // needs you shows both, either alone shows itself, and anything else
    // counts as idle.
    init(statuses: [String]) {
        let isBusy = statuses.contains(BarState.busy.rawValue)
        let isWaiting = statuses.contains(BarState.waiting.rawValue)

        switch (isBusy, isWaiting) {
        case (true, true):
            self = .busyWaiting
        case (false, true):
            self = .waiting
        case (true, false):
            self = .busy
        case (false, false):
            self = .idle
        }
    }
}

// The `bar` line.
struct BarEvent: Encodable {
    let event = "bar"
    let state: BarState
}

// The `sessions` line. `event` sorts first under .sortedKeys, so Hammerspoon
// can tell the two lines apart without decoding the long one.
struct SessionsEvent: Encodable {
    let event = "sessions"
    let profiles: [ProfileReport]
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
    static func sessions(for profile: Profile, agents: [AgentEntry]) -> [SessionReport] {
        let waitingByPid = Dictionary(agents.compactMap { entry in entry.pid.map { ($0, entry.waitingFor) } },
                                      uniquingKeysWith: { first, _ in first })

        return interactiveSessions(for: profile, waitingByPid: waitingByPid).sorted(by: isMoreUrgent)
    }

    // One report per `<pid>.json` whose process is still running.
    private static func interactiveSessions(for profile: Profile, waitingByPid: [Int32: String?]) -> [SessionReport] {
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
                                         waitingFor: waitingByPid[pid] ?? nil))
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

// MARK: - Stream

// The `watch` subcommand: while the panel is open, ticks every source on
// its own cadence and prints a line when what it found changed; it also
// pauses while nobody can see the screen. The bar state is kept current at
// all times, from file and process events rather than a tick.
final class ClaudeStatsStream {
    // How often each source is read while the panel is open.
    private static let sessionsSeconds = 2.0
    private static let agentsSeconds = 30.0
    // How soon after a session starts waiting the agents call may run again
    // to learn why. Several sessions flipping at once cost one call.
    private static let waitingRefreshSeconds = 5.0
    // How long FSEvents gathers session file writes into one callback. The
    // first write after a quiet spell is reported at once (NoDefer).
    private static let sessionsLatencySeconds = 0.3

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
    private let work = DispatchQueue(label: "c-claude-stats.work", qos: .utility)
    private let agentsWork = DispatchQueue(label: "c-claude-stats.agents", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    // Confined to `work`.
    private var agentsByProfile: [String: [AgentEntry]] = [:]
    private var lastSessionsLine: Data?
    private var waitingPids = Set<Int32>()
    private var lastWaitingRefresh = Date.distantPast
    private var agentsRunning = false
    private var lastBarState: BarState?
    private var exitWatches: [Int32: DispatchSourceProcess] = [:]
    // Pids whose exit fired but whose parent has not reaped them yet, so
    // they still answer kill(pid, 0). Dropped once their file is gone.
    private var exitedPids = Set<Int32>()
    // Whether the bar was last reported `away`; no file is read meanwhile.
    private var barAway = false

    // Confined to the main queue.
    private var away = Set<AwayReason>()
    // Whether the panel is open. Only the bar state is read while it is
    // closed.
    private var live = false
    private var timers: [DispatchSourceTimer] = []
    private var sessionsWatch: FSEventStreamRef?

    // Wires the sources up; nothing ticks until the panel goes live.
    init(profiles: [Profile], claudeExecutable: String, paneListScript: String) {
        self.profiles = profiles
        agentsCommand = AgentsCommand(executable: claudeExecutable)
        tmuxAgents = TmuxAgentPids(listScript: paneListScript)
    }

    // Begin: watch for the bar going out of sight, for stdin and for session
    // files, then tick.
    func start() {
        observeAway()
        watchStandardInput()
        watchSessionFiles()
        resume()
    }

    // Run every source once, synchronously, and print the sessions line: the
    // `once` subcommand.
    func runOnce() {
        work.sync {
            refreshAgentsNow()
            tickSessions()
        }
    }

    // MARK: Ticks

    // Re-read session files and limit caches, keep the sessions the tmux
    // picker lists, and print when anything changed.
    private func tickSessions() {
        let reports = zip(profiles, listedSessions()).map { profile, sessions in
            ProfileReport(name: profile.name, sessions: sessions, limits: LimitsCache.read(for: profile))
        }

        noticeNewlyWaiting(reports)

        guard let line = try? encoder.encode(SessionsEvent(profiles: reports)), line != lastSessionsLine else {
            return
        }

        lastSessionsLine = line
        emit(line)
    }

    // Every profile's live sessions that the tmux picker lists, in profile
    // order.
    private func listedSessions() -> [[SessionReport]] {
        let sessionsByProfile = profiles.map { profile in
            SessionsReader.sessions(for: profile, agents: agentsByProfile[profile.name] ?? [])
        }

        tmuxAgents.update(livePids: Set(sessionsByProfile.joined().map(\.pid)))

        return sessionsByProfile.map { sessions in sessions.filter { tmuxAgents.contains($0.pid) } }
    }

    // Re-read the session files, watch every busy or waiting pid for its
    // exit, and print the bar state when it changed. Agents and limits are
    // left to the panel's ticks: the bar needs neither. Skipped while away.
    private func tickBar() {
        guard !barAway else {
            return
        }

        let sessions = listedSessions().joined()

        exitedPids.formIntersection(sessions.map(\.pid))

        let working = sessions.filter { session in
            !exitedPids.contains(session.pid) && BarState.workingStatuses.contains(session.state)
        }

        watchExits(of: Set(working.map(\.pid)))
        printBar(BarState(statuses: working.map(\.state)))
    }

    // Nobody can see the screen: report the bar away so it stops animating,
    // and read nothing until somebody can.
    private func barWentAway() {
        guard !barAway else {
            return
        }

        barAway = true
        printBar(.away)
    }

    // The screen is in sight again: read the state the bar should show now.
    // It always prints, since the last line said away.
    private func barReturned() {
        guard barAway else {
            return
        }

        barAway = false
        tickBar()
    }

    // Keep one exit watch per pid in `pids` and cancel the rest.
    private func watchExits(of pids: Set<Int32>) {
        for (pid, source) in exitWatches where !pids.contains(pid) {
            source.cancel()
            exitWatches[pid] = nil
        }

        for pid in pids where exitWatches[pid] == nil {
            let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: work)

            source.setEventHandler { [self] in
                exitedPids.insert(pid)
                tickBar()
            }

            source.resume()
            exitWatches[pid] = source
        }
    }

    // Print the bar line when the state changed.
    private func printBar(_ state: BarState) {
        guard state != lastBarState, let line = try? encoder.encode(BarEvent(state: state)) else {
            return
        }

        lastBarState = state
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

    // Record one reason for being out of sight, then pause or resume, the
    // bar state included.
    private func setAway(_ reason: AwayReason, _ isAway: Bool) {
        if isAway {
            away.insert(reason)
        } else {
            away.remove(reason)
        }

        if away.isEmpty {
            resume()
            work.async { [self] in barReturned() }
        } else {
            pause()
            work.async { [self] in barWentAway() }
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

    // Read the bar state now and again whenever a file in any sessions/
    // directory changes. Claude Code rewrites a session file in place, which
    // a vnode source on the directory would miss; FSEvents file events do
    // not. Runs for the life of the process, panel open or not.
    private func watchSessionFiles() {
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let paths = profiles.map(\.sessionsDirectory.path) as CFArray
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents)

        sessionsWatch = FSEventStreamCreate(kCFAllocatorDefault, Self.sessionFilesChanged, &context, paths,
                                            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                            Self.sessionsLatencySeconds, flags)

        if let sessionsWatch {
            FSEventStreamSetDispatchQueue(sessionsWatch, work)
            FSEventStreamStart(sessionsWatch)
        }

        work.async { [self] in tickBar() }
    }

    // The FSEvents callback, on the work queue. `info` is the stream object,
    // which lives as long as the process does.
    private static let sessionFilesChanged: FSEventStreamCallback = { _, info, _, _, _, _ in
        guard let info else {
            return
        }

        Unmanaged<ClaudeStatsStream>.fromOpaque(info).takeUnretainedValue().tickBar()
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
