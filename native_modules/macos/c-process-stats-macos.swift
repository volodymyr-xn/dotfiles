// What the machine's processes are doing: the heaviest few by CPU, by energy
// and by memory, the load average they add up to, and how long they have had
// to accumulate any of it.
//
// One candidate list rather than three rankings, because the three overlap
// almost entirely and the caller has to re-rank two of them against its own
// previous call regardless — cumulative totals cannot say what is busy now.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the binary
// in ~/dotfiles/bin_native/macos/.
//
//   c-process-stats-macos     one JSON line, then exit
//
// Split out of c-sensor-temps-macos, which is named for the SMC and has no
// business walking the process table: different kernel interface, different
// failure modes, and nothing in common but the caller. The same split
// c-net-counters-macos was made for.
//
// One shot only, and no `watch` mode: the two streaming helpers feed a
// menubar row that repaints every couple of seconds, while this one answers
// a dropdown that has to be opened before anyone can read it. Walking several
// hundred processes on a timer would be work nobody asked for.
//
// Uptime and load average travel with the processes rather than with the
// sensors because that is what they are made of — load is the count of
// threads waiting for a turn, and uptime is the ceiling on every process age
// below.
//
// Foundation is deliberately not imported: Darwin covers everything here, and
// the reporting path formats its own decimals rather than reach for
// String(format:).

import Darwin

// A reading rendered with a fixed number of decimals. Fixed-point integer
// maths, because Foundation's String(format:) is the only thing this tool
// would import Foundation for.
struct DecimalText {
    let value: Float
    let decimals: Int

    var text: String {
        var scale = 1

        for _ in 0..<decimals {
            scale *= 10
        }

        let scaled = Int((value * Float(scale)).rounded())
        let whole = scaled / scale
        var fraction = String(scaled % scale)

        while fraction.count < decimals {
            fraction = "0" + fraction
        }

        return "\(whole).\(fraction)"
    }
}

// Rendering for the one-line JSON this tool emits, by hand because it does
// not import Foundation and so has no JSONSerialization.
//
// null rather than a stand-in number throughout, so a caller can tell "not
// readable" from "zero" and show a placeholder instead of a lie.
enum JSON {
    static func number(_ value: Float?, decimals: Int) -> String {
        guard let value else {
            return "null"
        }

        return DecimalText(value: value, decimals: decimals).text
    }

    static func integer(_ value: Int?) -> String {
        guard let value else {
            return "null"
        }

        return "\(value)"
    }

    static func integer(_ value: UInt64?) -> String {
        guard let value else {
            return "null"
        }

        return "\(value)"
    }

    // A process is named after an executable on disk, and an executable may
    // legally be named anything — which makes this the one string in the
    // dotfiles' JSON that genuinely needs escaping.
    static func text(_ value: String?) -> String {
        guard let value else {
            return "null"
        }

        var escaped = ""

        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"":
                escaped += "\\\""
            case "\\":
                escaped += "\\\\"
            default:
                if scalar.value >= 0x20 {
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }

        return #""\#(escaped)""#
    }

    // Raw string delimiters so the quotes around a key are quotes rather than
    // backslash-escapes; `\#(…)` is interpolation inside one.
    static func object(_ fields: [(name: String, value: String)]) -> String {
        "{" + fields.map { #""\#($0.name)":\#($0.value)"# }.joined(separator: ",") + "}"
    }

    static func array(_ values: [String]) -> String {
        "[" + values.joined(separator: ",") + "]"
    }
}

// Seconds since boot, off the same `kern.boottime` uptime(1) reads.
struct SystemUptime {
    private static let name = "kern.boottime"

    static func seconds() -> UInt64? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride

        guard sysctlbyname(name, &boot, &size, nil, 0) == 0, boot.tv_sec > 0 else {
            return nil
        }

        let now = time(nil)

        guard now > boot.tv_sec else {
            return nil
        }

        return UInt64(now - boot.tv_sec)
    }
}

// The 1, 5 and 15 minute load averages, the three uptime(1) prints. Load
// counts runnable threads rather than busy time, so it says something the CPU
// percentages do not: a machine at 20% with a load of twelve is waiting on
// something.
struct LoadAverage {
    private static let windowCount = 3

    static func values() -> [Float]? {
        var averages = [Double](repeating: 0, count: windowCount)

        guard getloadavg(&averages, Int32(windowCount)) == Int32(windowCount) else {
            return nil
        }

        return averages.map(Float.init)
    }
}

// One process as the report carries it.
//
// Cumulative CPU time and energy rather than a rate: a rate needs two samples
// and this command takes one. The caller diffs two calls when it has them and
// falls back to the mean over the process's life when it does not.
// `ageSeconds` is what makes that work without a clock on the other side —
// the difference between two of them is exactly the wall time between the two
// calls, however late either one arrived.
struct ProcessSample {
    let pid: pid_t
    let name: String
    let cpuMilliseconds: UInt64
    let energyNanojoules: UInt64?
    let residentBytes: UInt64
    let ageSeconds: UInt64
}

// Every process this user can ask about, with what it has burned and what it
// is holding.
//
// Processes owned by another user do not answer PROC_PIDTASKALLINFO without
// privileges and are skipped, which leaves the ones worth naming in a menu: a
// root daemon is never the answer to "what is eating my machine".
struct ProcessTable {
    private static let nanosecondsPerMillisecond: UInt64 = 1_000_000

    // proc_taskinfo reports CPU time in mach absolute time units, not in
    // nanoseconds — the two are the same on Intel and differ by a factor of
    // 24 on Apple Silicon, where the tick is 125/3 ns. Read once: the ratio is
    // fixed for the life of the boot.
    private static let timebase: mach_timebase_info_data_t = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)

        return timebase
    }()

    private static func milliseconds(ofTicks ticks: UInt64) -> UInt64 {
        guard timebase.denom > 0 else {
            return 0
        }

        return ticks * UInt64(timebase.numer) / UInt64(timebase.denom) / nanosecondsPerMillisecond
    }

    // A fixed-size C character array as a String. proc_bsdinfo declares its
    // names that way, and Swift imports such an array as a tuple with no
    // reading of its own.
    private static func string<T>(from characters: T) -> String {
        var characters = characters

        return withUnsafePointer(to: &characters) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }

    // pbi_name carries the full name and pbi_comm its 16-character
    // truncation; a kernel thread has only the latter.
    private static func name(of info: proc_bsdinfo) -> String {
        let full = string(from: info.pbi_name)

        if !full.isEmpty {
            return full
        }

        return string(from: info.pbi_comm)
    }

    // Energy the process has drawn since it started, in nanojoules, measured
    // by the kernel rather than modelled: `ri_energy_nj` landed in
    // rusage_info_v6 with macOS 15, and nil here is an older system rather
    // than a process that drew nothing.
    //
    // Not to be confused with `ri_billed_energy`, which is a couple of fields
    // above it and stays at zero however hard a process works — that pair
    // accounts for energy billed between coalitions, not consumption.
    //
    // These figures do not add up to what the machine draws at the wall: the
    // display, the SSD, memory and the idle SoC belong to no process. They
    // rank processes against each other, which is all the panel asks of them.
    private static func energyNanojoules(of pid: pid_t) -> UInt64? {
        var usage = rusage_info_v6()
        let read = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }

        guard read == 0 else {
            return nil
        }

        return usage.ri_energy_nj
    }

    private static func sample(of pid: pid_t, now: time_t) -> ProcessSample? {
        var info = proc_taskallinfo()
        let size = Int32(MemoryLayout<proc_taskallinfo>.size)

        guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) == size else {
            return nil
        }

        let started = time_t(info.pbsd.pbi_start_tvsec)
        let ticks = info.ptinfo.pti_total_user + info.ptinfo.pti_total_system

        return ProcessSample(pid: pid,
                             name: name(of: info.pbsd),
                             cpuMilliseconds: milliseconds(ofTicks: ticks),
                             energyNanojoules: energyNanojoules(of: pid),
                             residentBytes: info.ptinfo.pti_resident_size,
                             ageSeconds: now > started ? UInt64(now - started) : 0)
    }

    static func all() -> [ProcessSample] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)

        guard byteCount > 0 else {
            return []
        }

        var pids = [pid_t](repeating: 0, count: Int(byteCount) / MemoryLayout<pid_t>.size)
        let written = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, byteCount)

        guard written > 0 else {
            return []
        }

        let now = time(nil)
        var samples: [ProcessSample] = []

        for pid in pids.prefix(Int(written) / MemoryLayout<pid_t>.size) where pid > 0 {
            guard let sample = sample(of: pid, now: now) else {
                continue
            }

            samples.append(sample)
        }

        return samples
    }

    // The heaviest few by whichever measure is handed in.
    static func heaviest(_ samples: [ProcessSample], by measure: (ProcessSample) -> UInt64,
                         count: Int) -> [ProcessSample] {
        Array(samples.sorted { measure($0) > measure($1) }.prefix(count))
    }

    // One list rather than one per ranking, because the three overlap almost
    // entirely and the caller ranks them itself anyway. Deep on the two
    // cumulative measures, which need the depth (see the counts below), and
    // shallow on resident memory, which does not.
    static func candidates(_ samples: [ProcessSample],
                           cumulativeCount: Int, residentCount: Int) -> [ProcessSample] {
        var chosen: [pid_t: ProcessSample] = [:]

        for sample in heaviest(samples, by: { $0.cpuMilliseconds }, count: cumulativeCount) {
            chosen[sample.pid] = sample
        }

        for sample in heaviest(samples, by: { $0.energyNanojoules ?? 0 }, count: cumulativeCount) {
            chosen[sample.pid] = sample
        }

        for sample in heaviest(samples, by: { $0.residentBytes }, count: residentCount) {
            chosen[sample.pid] = sample
        }

        // Sorted so two runs of the command produce the same order, which is
        // what makes the output diffable by eye.
        return chosen.values.sorted { $0.pid < $1.pid }
    }
}

// The readings the command reports, and their JSON rendering.
struct ProcessReport {
    private static let loadDecimals = 2

    let uptimeSeconds: UInt64?
    let loadAverages: [Float]?
    let candidates: [ProcessSample]

    private var processes: String {
        JSON.array(candidates.map {
            JSON.object([
                ("pid", JSON.integer(Int($0.pid))),
                ("name", JSON.text($0.name)),
                ("cpu_ms", JSON.integer($0.cpuMilliseconds)),
                ("energy_nj", JSON.integer($0.energyNanojoules)),
                ("rss_bytes", JSON.integer($0.residentBytes)),
                ("age_seconds", JSON.integer($0.ageSeconds)),
            ])
        })
    }

    // One line per key, so adding a reading is one line and the name sits
    // next to the value it carries.
    var json: String {
        JSON.object([
            ("uptime_seconds", JSON.integer(uptimeSeconds)),
            ("load_avg", JSON.array((loadAverages ?? []).map {
                JSON.number($0, decimals: Self.loadDecimals)
            })),
            ("processes", processes),
        ])
    }
}

// Entry point: walk the table once, rank it twice, print, exit.
struct ProcessStatsCommand {
    // How deep the candidate list goes. CPU time and energy are cumulative,
    // which is a poor proxy for what is busy now: the caller re-ranks against
    // its own previous call, so the list has to be deep enough that a process
    // which only started working recently is in it at all. A hundred entries
    // reaches about a second of accumulated CPU on a freshly booted machine —
    // anything busy for longer than that is a candidate.
    //
    // Resident memory is measured rather than accumulated, so its top few are
    // already the answer and need no depth behind them.
    private static let cumulativeCandidateCount = 100
    private static let residentCandidateCount = 20

    func run() -> Never {
        let processes = ProcessTable.all()
        let report = ProcessReport(
            uptimeSeconds: SystemUptime.seconds(),
            loadAverages: LoadAverage.values(),
            candidates: ProcessTable.candidates(processes,
                                                cumulativeCount: Self.cumulativeCandidateCount,
                                                residentCount: Self.residentCandidateCount))

        print(report.json)
        exit(0)
    }
}

ProcessStatsCommand().run()
