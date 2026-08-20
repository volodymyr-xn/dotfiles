// What the machine's processes are doing: the heaviest few by CPU, by energy
// and by memory, the load average they add up to, and how long they have had
// to accumulate any of it.
//
// A D port of c-process-stats-macos.swift, byte-for-byte identical in output.
// The two differ only in what the toolchain hands them: Swift imports Darwin
// and gets the process-info structs for free, while D has to declare every one
// of them below against <sys/proc_info.h> and <sys/resource.h>.
//
// One candidate list rather than three rankings, because the three overlap
// almost entirely and the caller has to re-rank two of them against its own
// previous call regardless — cumulative totals cannot say what is busy now.
//
// Not wired into dotfiles_setup/build_native_modules.sh: that script names a
// binary after its source file, so building both would have the two fight over
// bin_native/macos/c-process-stats-macos. Build it by hand with
// `ldc2 -O -of=<name> c-process-stats-macos.d`, and pick which of the two the
// setup script owns before either is put on PATH.
//
// One JSON line, then exit.
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

module c_process_stats_macos;

import core.stdc.stdlib : exit;
import core.stdc.time : time, time_t;
import core.sys.posix.sys.time : timeval;
import std.algorithm.iteration : map;
import std.algorithm.sorting : sort;
import std.array : array, join;
import std.conv : to;
import std.math : round;
import std.stdio : writeln;
import std.typecons : Nullable, nullable;

// The C declarations this tool needs. Grouped here rather than spread through
// the file so the boundary between "what the kernel says" and "what this
// program does with it" stays one block wide.
extern (C) {
    alias pid_t = int;

    // <mach/mach_time.h>. Two fields, and the only reason CPU ticks can be
    // turned into milliseconds at all.
    struct mach_timebase_info_data_t {
        uint numer;
        uint denom;
    }

    int mach_timebase_info(mach_timebase_info_data_t* info);

    // <sys/proc_info.h>. pbi_comm is MAXCOMLEN, pbi_name twice that; every
    // other field is here only to keep the offsets right.
    struct proc_bsdinfo {
        uint pbi_flags;
        uint pbi_status;
        uint pbi_xstatus;
        uint pbi_pid;
        uint pbi_ppid;
        uint pbi_uid;
        uint pbi_gid;
        uint pbi_ruid;
        uint pbi_rgid;
        uint pbi_svuid;
        uint pbi_svgid;
        uint rfu_1;
        char[16] pbi_comm;
        char[32] pbi_name;
        uint pbi_nfiles;
        uint pbi_pgid;
        uint pbi_pjobc;
        uint e_tdev;
        uint e_tpgid;
        int pbi_nice;
        ulong pbi_start_tvsec;
        ulong pbi_start_tvusec;
    }

    struct proc_taskinfo {
        ulong pti_virtual_size;
        ulong pti_resident_size;
        ulong pti_total_user;
        ulong pti_total_system;
        ulong pti_threads_user;
        ulong pti_threads_system;
        int pti_policy;
        int pti_faults;
        int pti_pageins;
        int pti_cow_faults;
        int pti_messages_sent;
        int pti_messages_received;
        int pti_syscalls_mach;
        int pti_syscalls_unix;
        int pti_csw;
        int pti_threadnum;
        int pti_numrunning;
        int pti_priority;
    }

    struct proc_taskallinfo {
        proc_bsdinfo pbsd;
        proc_taskinfo ptinfo;
    }

    // <sys/resource.h>. Only ri_energy_nj is read; the fields above it are
    // padding as far as this tool is concerned, and the ones below keep the
    // struct the size the kernel expects.
    struct rusage_info_v6 {
        ubyte[16] ri_uuid;
        ulong ri_user_time;
        ulong ri_system_time;
        ulong ri_pkg_idle_wkups;
        ulong ri_interrupt_wkups;
        ulong ri_pageins;
        ulong ri_wired_size;
        ulong ri_resident_size;
        ulong ri_phys_footprint;
        ulong ri_proc_start_abstime;
        ulong ri_proc_exit_abstime;
        ulong ri_child_user_time;
        ulong ri_child_system_time;
        ulong ri_child_pkg_idle_wkups;
        ulong ri_child_interrupt_wkups;
        ulong ri_child_pageins;
        ulong ri_child_elapsed_abstime;
        ulong ri_diskio_bytesread;
        ulong ri_diskio_byteswritten;
        ulong ri_cpu_time_qos_default;
        ulong ri_cpu_time_qos_maintenance;
        ulong ri_cpu_time_qos_background;
        ulong ri_cpu_time_qos_utility;
        ulong ri_cpu_time_qos_legacy;
        ulong ri_cpu_time_qos_user_initiated;
        ulong ri_cpu_time_qos_user_interactive;
        ulong ri_billed_system_time;
        ulong ri_serviced_system_time;
        ulong ri_logical_writes;
        ulong ri_lifetime_max_phys_footprint;
        ulong ri_instructions;
        ulong ri_cycles;
        ulong ri_billed_energy;
        ulong ri_serviced_energy;
        ulong ri_interval_max_phys_footprint;
        ulong ri_runnable_time;
        ulong ri_flags;
        ulong ri_user_ptime;
        ulong ri_system_ptime;
        ulong ri_pinstructions;
        ulong ri_pcycles;
        ulong ri_energy_nj;
        ulong ri_penergy_nj;
        ulong ri_secure_time_in_system;
        ulong ri_secure_ptime_in_system;
        ulong ri_neural_footprint;
        ulong ri_lifetime_max_neural_footprint;
        ulong ri_interval_max_neural_footprint;
        ulong[9] ri_reserved;
    }

    int proc_listpids(uint type, uint typeinfo, void* buffer, int buffersize);
    int proc_pidinfo(pid_t pid, int flavor, ulong arg, void* buffer, int buffersize);
    // rusage_info_t is itself `void *`, so the buffer argument is a `void **`.
    int proc_pid_rusage(pid_t pid, int flavor, void** buffer);

    int sysctlbyname(const(char)* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen);
    int getloadavg(double* loadavg, int nelem);
}

enum PROC_ALL_PIDS = 1;
enum PROC_PIDTASKALLINFO = 2;
enum RUSAGE_INFO_V6 = 6;

// A reading rendered with a fixed number of decimals. Fixed-point integer
// maths, because printf-style formatting rounds on its own terms and the
// Swift original hand-rolls the same arithmetic.
struct DecimalText {
    float value;
    int decimals;

    string text() const {
        long scale = 1;

        foreach (_; 0 .. decimals) {
            scale *= 10;
        }

        const scaled = cast(long) round(value * scale);
        const whole = scaled / scale;
        auto fraction = (scaled % scale).to!string;

        while (fraction.length < decimals) {
            fraction = "0" ~ fraction;
        }

        return whole.to!string ~ "." ~ fraction;
    }
}

// Rendering for the one-line JSON this tool emits, by hand because the shape
// is fixed and a serializer would cost more than it saves.
//
// null rather than a stand-in number throughout, so a caller can tell "not
// readable" from "zero" and show a placeholder instead of a lie.
struct JSON {
    static string number(float value, int decimals) {
        return DecimalText(value, decimals).text;
    }

    static string integer(T)(Nullable!T value) {
        if (value.isNull) {
            return "null";
        }

        return value.get.to!string;
    }

    static string integer(T)(T value) {
        return value.to!string;
    }

    // A process is named after an executable on disk, and an executable may
    // legally be named anything — which makes this the one string in the
    // dotfiles' JSON that genuinely needs escaping.
    //
    // Iterated as bytes rather than as code points: every byte of a multi-byte
    // UTF-8 sequence is >= 0x80, so passing them through unexamined preserves
    // the encoding and costs no decoding.
    static string text(string value) {
        string escaped;

        foreach (character; value) {
            switch (character) {
            case '"':
                escaped ~= `\"`;
                break;
            case '\\':
                escaped ~= `\\`;
                break;
            default:
                if (character >= 0x20) {
                    escaped ~= character;
                }
            }
        }

        return `"` ~ escaped ~ `"`;
    }

    static string object(const(string[2])[] fields) {
        return "{" ~ fields.map!(field => `"` ~ field[0] ~ `":` ~ field[1]).join(",") ~ "}";
    }

    static string array_(const(string)[] values) {
        return "[" ~ values.join(",") ~ "]";
    }
}

// Seconds since boot, off the same `kern.boottime` uptime(1) reads.
struct SystemUptime {
    private enum name = "kern.boottime";

    static Nullable!ulong seconds() {
        timeval boot;
        size_t size = timeval.sizeof;

        if (sysctlbyname(name.ptr, &boot, &size, null, 0) != 0 || boot.tv_sec <= 0) {
            return Nullable!ulong.init;
        }

        const now = time(null);

        if (now <= boot.tv_sec) {
            return Nullable!ulong.init;
        }

        return nullable(cast(ulong)(now - boot.tv_sec));
    }
}

// The 1, 5 and 15 minute load averages, the three uptime(1) prints. Load
// counts runnable threads rather than busy time, so it says something the CPU
// percentages do not: a machine at 20% with a load of twelve is waiting on
// something.
struct LoadAverage {
    private enum windowCount = 3;

    static float[] values() {
        double[windowCount] averages = 0;

        if (getloadavg(averages.ptr, windowCount) != windowCount) {
            return null;
        }

        return averages[].map!(average => cast(float) average).array;
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
    pid_t pid;
    string name;
    ulong cpuMilliseconds;
    Nullable!ulong energyNanojoules;
    ulong residentBytes;
    ulong ageSeconds;
}

// Every process this user can ask about, with what it has burned and what it
// is holding.
//
// Processes owned by another user do not answer PROC_PIDTASKALLINFO without
// privileges and are skipped, which leaves the ones worth naming in a menu: a
// root daemon is never the answer to "what is eating my machine".
struct ProcessTable {
    private enum nanosecondsPerMillisecond = 1_000_000;

    // proc_taskinfo reports CPU time in mach absolute time units, not in
    // nanoseconds — the two are the same on Intel and differ by a factor of
    // 24 on Apple Silicon, where the tick is 125/3 ns. Read once: the ratio is
    // fixed for the life of the boot.
    private static mach_timebase_info_data_t timebase;

    private static ulong milliseconds(ulong ticks) {
        if (timebase.denom == 0) {
            return 0;
        }

        return ticks * timebase.numer / timebase.denom / nanosecondsPerMillisecond;
    }

    // A fixed-size C character array as a string. The kernel writes a NUL
    // terminator when the name fits and fills the array when it does not, so
    // the terminator cannot be assumed.
    private static string text(const(char)[] characters) {
        foreach (index, character; characters) {
            if (character == '\0') {
                return characters[0 .. index].idup;
            }
        }

        return characters.idup;
    }

    // pbi_name carries the full name and pbi_comm its 16-character
    // truncation; a kernel thread has only the latter.
    private static string name(ref const proc_bsdinfo info) {
        const full = text(info.pbi_name);

        if (full.length > 0) {
            return full;
        }

        return text(info.pbi_comm);
    }

    // Energy the process has drawn since it started, in nanojoules, measured
    // by the kernel rather than modelled: `ri_energy_nj` landed in
    // rusage_info_v6 with macOS 15, and null here is an older system rather
    // than a process that drew nothing.
    //
    // Not to be confused with `ri_billed_energy`, which is a couple of fields
    // above it and stays at zero however hard a process works — that pair
    // accounts for energy billed between coalitions, not consumption.
    //
    // These figures do not add up to what the machine draws at the wall: the
    // display, the SSD, memory and the idle SoC belong to no process. They
    // rank processes against each other, which is all the panel asks of them.
    private static Nullable!ulong energyNanojoules(pid_t pid) {
        rusage_info_v6 usage;

        if (proc_pid_rusage(pid, RUSAGE_INFO_V6, cast(void**)&usage) != 0) {
            return Nullable!ulong.init;
        }

        return nullable(usage.ri_energy_nj);
    }

    private static Nullable!ProcessSample sample(pid_t pid, time_t now) {
        proc_taskallinfo info;
        const size = cast(int) proc_taskallinfo.sizeof;

        if (proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) != size) {
            return Nullable!ProcessSample.init;
        }

        const started = cast(time_t) info.pbsd.pbi_start_tvsec;
        const ticks = info.ptinfo.pti_total_user + info.ptinfo.pti_total_system;

        return nullable(ProcessSample(pid,
                name(info.pbsd),
                milliseconds(ticks),
                energyNanojoules(pid),
                info.ptinfo.pti_resident_size,
                now > started ? cast(ulong)(now - started) : 0));
    }

    static ProcessSample[] all() {
        mach_timebase_info(&timebase);

        const byteCount = proc_listpids(PROC_ALL_PIDS, 0, null, 0);

        if (byteCount <= 0) {
            return null;
        }

        auto pids = new pid_t[byteCount / pid_t.sizeof];
        const written = proc_listpids(PROC_ALL_PIDS, 0, pids.ptr, byteCount);

        if (written <= 0) {
            return null;
        }

        const now = time(null);
        ProcessSample[] samples;

        foreach (pid; pids[0 .. written / pid_t.sizeof]) {
            if (pid <= 0) {
                continue;
            }

            auto reading = sample(pid, now);

            if (reading.isNull) {
                continue;
            }

            samples ~= reading.get;
        }

        return samples;
    }

    // The heaviest few by whichever measure is handed in.
    static ProcessSample[] heaviest(ProcessSample[] samples,
            ulong delegate(ref const ProcessSample) measure, size_t count) {
        auto ranked = samples.dup;
        ranked.sort!((a, b) => measure(a) > measure(b));

        return ranked[0 .. count < ranked.length ? count : ranked.length];
    }

    // One list rather than one per ranking, because the three overlap almost
    // entirely and the caller ranks them itself anyway. Deep on the two
    // cumulative measures, which need the depth (see the counts below), and
    // shallow on resident memory, which does not.
    static ProcessSample[] candidates(ProcessSample[] samples,
            size_t cumulativeCount, size_t residentCount) {
        ProcessSample[pid_t] chosen;

        foreach (sample; heaviest(samples, (ref const sample) => sample.cpuMilliseconds,
                cumulativeCount)) {
            chosen[sample.pid] = sample;
        }

        foreach (sample; heaviest(samples,
                (ref const sample) => sample.energyNanojoules.isNull ? 0
                    : sample.energyNanojoules.get, cumulativeCount)) {
            chosen[sample.pid] = sample;
        }

        foreach (sample; heaviest(samples, (ref const sample) => sample.residentBytes,
                residentCount)) {
            chosen[sample.pid] = sample;
        }

        // Sorted so two runs of the command produce the same order, which is
        // what makes the output diffable by eye.
        return chosen.values.sort!((a, b) => a.pid < b.pid).release;
    }
}

// The readings the command reports, and their JSON rendering.
struct ProcessReport {
    private enum loadDecimals = 2;

    Nullable!ulong uptimeSeconds;
    float[] loadAverages;
    ProcessSample[] candidates;

    private string processes() const {
        return JSON.array_(candidates.map!(candidate => JSON.object([
                ["pid", JSON.integer(candidate.pid)],
                ["name", JSON.text(candidate.name)],
                ["cpu_ms", JSON.integer(candidate.cpuMilliseconds)],
                ["energy_nj", JSON.integer(candidate.energyNanojoules)],
                ["rss_bytes", JSON.integer(candidate.residentBytes)],
                ["age_seconds", JSON.integer(candidate.ageSeconds)],
        ])).array);
    }

    // One line per key, so adding a reading is one line and the name sits
    // next to the value it carries.
    string json() const {
        return JSON.object([
            ["uptime_seconds", JSON.integer(uptimeSeconds)],
            ["load_avg", JSON.array_(loadAverages
                    .map!(average => JSON.number(average, loadDecimals)).array)],
            ["processes", processes],
        ]);
    }
}

// How deep the candidate list goes. CPU time and energy are cumulative,
// which is a poor proxy for what is busy now: the caller re-ranks against
// its own previous call, so the list has to be deep enough that a process
// which only started working recently is in it at all. A hundred entries
// reaches about a second of accumulated CPU on a freshly booted machine —
// anything busy for longer than that is a candidate.
//
// Resident memory is measured rather than accumulated, so its top few are
// already the answer and need no depth behind them.
enum cumulativeCandidateCount = 100;
enum residentCandidateCount = 20;

// Entry point: walk the table once, rank it twice, print, exit.
void main() {
    auto processes = ProcessTable.all();
    const report = ProcessReport(
        SystemUptime.seconds(),
        LoadAverage.values(),
        ProcessTable.candidates(processes, cumulativeCandidateCount, residentCandidateCount));

    writeln(report.json);
    exit(0);
}
