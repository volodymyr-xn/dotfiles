// Read Apple Silicon CPU and GPU die temperatures from the SMC, report the
// hottest and mean sensor in each group, and add the GPU's current
// utilisation, the whole machine's power draw, swap and physical memory.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the
// binary in ~/dotfiles/bin_native/macos/. The source lives in
// native_modules/ because it is compiled rather than interpreted; only the
// built artefact goes on PATH, and only on macOS.
//
//   c-sensor-temps-macos           one JSON line, then exit
//   c-sensor-temps-macos watch     a line every second until killed
//   c-sensor-temps-macos watch 250 the same at another interval
//   c-sensor-temps-macos details   one much larger JSON line, then exit
//   c-sensor-temps-macos list      every readable T-prefixed sensor, one per line
//   c-sensor-temps-macos list P    the same for the P-prefixed power keys
//
// Two report shapes, because the two callers want opposite things. The
// default and `watch` carry only what a menubar row can show — four
// readings, small enough to stream every couple of seconds forever.
// `details` is the one a dropdown asks for when it opens: every die sensor
// named separately, the GPU, and total memory. None of that is worth a
// kernel round-trip twice a second.
//
// Network counters live in c-net-counters-macos, and processes, uptime and
// load average in c-process-stats-macos. Throughput wants a faster cadence
// than system_stats does; the process table wants a far slower one and comes
// from a kernel interface this tool never touches.
//
// CPU utilisation is deliberately absent: the caller (Hammerspoon) already
// has hs.host.cpuUsage(), while GPU utilisation has no equivalent there and
// has to come from the IORegistry.
//
// Why not macmon: `macmon pipe` only emits cpu_temp_avg and gpu_temp_avg —
// there is no per-sensor breakdown, so a maximum cannot be recovered from it.
//
// Why not the IOHID sensor API: on this M4 the HID temperature services are
// named "PMU tdie*", "PMU tdev*", "NAND CH0 temp" and "gas gauge battery" —
// none of them attributable to the CPU or the GPU. The SMC keys are.
//
// The key sets below are per-SoC and will be wrong on any other chip. They
// mirror exelban/stats Modules/Sensors/values.swift for the M4 generation.
// When this stops reporting, run `c-sensor-temps-macos list` and re-derive
// them.
//
// Foundation is deliberately not imported: Darwin and IOKit cover
// everything here, and the reporting path formats its own decimals rather
// than reach for String(format:).

import Darwin
import IOKit

struct SMCVersion {
    var major: CUnsignedChar = 0
    var minor: CUnsignedChar = 0
    var build: CUnsignedChar = 0
    var reserved: CUnsignedChar = 0
    var release: CUnsignedShort = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// The 80-byte request/response struct the AppleSMC user client expects.
// Field order and the explicit padding are load-bearing — the kernel reads
// this by offset, so a reordered member silently returns garbage.
struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    // The first four payload bytes, little-endian — how a "flt " value
    // arrives.
    var littleEndianWord: UInt32 {
        UInt32(bytes.0) | (UInt32(bytes.1) << 8)
            | (UInt32(bytes.2) << 16) | (UInt32(bytes.3) << 24)
    }

    // The same four bytes big-endian — how a "ui32" value such as the key
    // count arrives.
    var bigEndianWord: UInt32 {
        (UInt32(bytes.0) << 24) | (UInt32(bytes.1) << 16)
            | (UInt32(bytes.2) << 8) | UInt32(bytes.3)
    }
}

// A four-character SMC key, held as the big-endian word the kernel wants.
struct SMCKey {
    private static let temperaturePrefix = UInt32(UInt8(ascii: "T"))

    let code: UInt32

    init(code: UInt32) {
        self.code = code
    }

    // Pack the four characters of a key name into that word.
    init(_ name: String) {
        var code: UInt32 = 0

        for scalar in name.unicodeScalars {
            code = (code << 8) + UInt32(scalar.value)
        }

        self.code = code
    }

    // Unpack the word back into its printable four characters.
    var name: String {
        let characters = [UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff),
                          UInt8((code >> 8) & 0xff), UInt8(code & 0xff)]

        return String(decoding: characters, as: UTF8.self)
    }

    // Temperature sensors are the T-prefixed keys. Compared as a byte so a
    // whole-table walk does not build a String per entry.
    var isTemperatureSensor: Bool {
        (code >> 24) & 0xff == Self.temperaturePrefix
    }

    // Same test against any prefix character, for the key listing.
    func hasPrefix(_ character: UInt8) -> Bool {
        UInt8((code >> 24) & 0xff) == character
    }
}

// An open AppleSMC user client. Reading needs no root and no entitlement;
// only writing (fan control) does. The connection is left to the process
// exit rather than closed explicitly — this is a one-shot command.
struct SMCConnection {
    // Selector for the single SMC user-client method; everything is
    // dispatched through it by setting `data8` on the request.
    private static let kernelIndex: UInt32 = 2

    // `data8` values: fetch a key's payload, walk the key table by index,
    // and fetch a key's size and type respectively.
    private static let readBytes: UInt8 = 5
    private static let getKeyFromIndex: UInt8 = 8
    private static let getKeyInfo: UInt8 = 9

    // Apple Silicon temperature keys are IEEE-754 singles, tagged "flt ".
    private static let floatType = SMCKey("flt ").code
    private static let floatSize: UInt32 = 4

    // Readings outside this range are a stale or misidentified key, not a
    // temperature.
    private static let plausibleCelsius: ClosedRange<Float> = 1.0...150.0

    // The key holding how many entries the SMC key table has: a big-endian
    // ui32, so four bytes like a float.
    private static let keyCountKey = SMCKey("#KEY")

    private let port: io_connect_t

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSMC"))

        guard service != 0 else {
            return nil
        }

        var port: io_connect_t = 0
        let opened = IOServiceOpen(service, mach_task_self_, 0, &port)
        IOObjectRelease(service)

        guard opened == kIOReturnSuccess else {
            return nil
        }

        self.port = port
    }

    // Round-trip one request through the user client. nil means the call
    // failed or the SMC rejected it, which is the normal answer for an
    // absent key.
    private func call(_ request: SMCParamStruct) -> SMCParamStruct? {
        var input = request
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let status = IOConnectCallStructMethod(port, Self.kernelIndex,
                                               &input, MemoryLayout<SMCParamStruct>.stride,
                                               &output, &outputSize)

        guard status == kIOReturnSuccess, output.result == 0 else {
            return nil
        }

        return output
    }

    // Read four bytes from a key, whatever they mean.
    private func word(of key: SMCKey) -> SMCParamStruct? {
        var request = SMCParamStruct()
        request.key = key.code
        request.keyInfo.dataSize = Self.floatSize
        request.data8 = Self.readBytes

        return call(request)
    }

    // Read a known 4-byte "flt " key, skipping the GET_KEY_INFO probe: the
    // curated sets below are all floats, and halving the kernel round-trips
    // per key is most of this tool's runtime.
    func float(of key: SMCKey) -> Float? {
        guard let payload = word(of: key) else {
            return nil
        }

        return Float(bitPattern: payload.littleEndianWord)
    }

    // The same read for a temperature key, where a value outside the
    // plausible range means the key was misidentified rather than that the
    // machine is that cold. Mirrors the same guard in macmon.
    func temperature(of key: SMCKey) -> Float? {
        guard let celsius = float(of: key),
              Self.plausibleCelsius.contains(celsius) else {
            return nil
        }

        return celsius
    }

    // Same read, but for a key of unknown provenance and with no idea what
    // the value means: ask the SMC for its type first, so the whole-table
    // walk never reinterprets a ui8 or an sp78 as a float.
    func probedFloat(of key: SMCKey) -> Float? {
        var request = SMCParamStruct()
        request.key = key.code
        request.data8 = Self.getKeyInfo

        guard let info = call(request),
              info.keyInfo.dataType == Self.floatType,
              info.keyInfo.dataSize == Self.floatSize,
              let payload = word(of: key) else {
            return nil
        }

        return Float(bitPattern: payload.littleEndianWord)
    }

    // How many entries the key table holds, which bounds the walk below.
    private func keyCount() -> UInt32? {
        word(of: Self.keyCountKey)?.bigEndianWord
    }

    // Walk the whole key table and collect every key starting with one
    // character — "T" for temperatures, "P" for power. This is the recovery
    // path when the curated sets below stop resolving.
    func keys(withPrefix character: UInt8) -> [SMCKey]? {
        guard let total = keyCount() else {
            return nil
        }

        var keys: [SMCKey] = []

        for index in 0..<total {
            var request = SMCParamStruct()
            request.data8 = Self.getKeyFromIndex
            request.data32 = index

            guard let entry = call(request) else {
                continue
            }

            let key = SMCKey(code: entry.key)

            if key.hasPrefix(character) {
                keys.append(key)
            }
        }

        return keys
    }
}

// A CFString for a literal, built the Core Foundation way because this tool
// does not import Foundation and so has no String bridging.
func cfString(_ text: String) -> CFString {
    CFStringCreateWithCString(nil, text, CFStringBuiltInEncodings.UTF8.rawValue)
}

// GPU load, straight out of the accelerator's own performance counters.
// The same numbers Activity Monitor's GPU history draws, and the only
// route to them: there is no SMC key for utilisation.
struct AcceleratorUsage {
    // Matching on the base class picks up whichever AGXAccelerator
    // subclass this SoC actually publishes.
    private static let serviceClass = "IOAccelerator"
    private static let statisticsProperty = "PerformanceStatistics"
    private static let utilizationKey = "Device Utilization %"

    // Percentage of the GPU busy right now, or nil when the registry entry
    // is missing or shaped differently than expected.
    static func percent() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching(serviceClass))

        guard service != 0 else {
            return nil
        }

        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service,
                                                             cfString(statisticsProperty),
                                                             kCFAllocatorDefault, 0) else {
            return nil
        }

        let statistics = property.takeRetainedValue()

        guard CFGetTypeID(statistics) == CFDictionaryGetTypeID() else {
            return nil
        }

        let dictionary = unsafeBitCast(statistics, to: CFDictionary.self)
        let key = cfString(utilizationKey)

        // Unmanaged rather than unsafeBitCast: the key has to stay alive
        // across the lookup, and a bitcast hands ARC no reason to keep it.
        guard let rawValue = CFDictionaryGetValue(dictionary,
                                                  Unmanaged.passUnretained(key).toOpaque()) else {
            return nil
        }

        let value = Unmanaged<CFNumber>.fromOpaque(rawValue).takeUnretainedValue()

        guard CFGetTypeID(value) == CFNumberGetTypeID() else {
            return nil
        }

        var utilization: Int64 = 0

        guard CFNumberGetValue(value, .sInt64Type, &utilization) else {
            return nil
        }

        return Int(utilization)
    }
}

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

// One named sensor and what it currently reads.
struct SensorReading {
    let key: String
    let celsius: Float
}

// One curated set of sensor keys, reduced to the single hottest reading.
struct SensorGroup {
    // SMC keys carrying live CPU core die temperatures on the M4
    // generation: four efficiency cores followed by eight performance-core
    // sensors.
    static let cpu = SensorGroup(keyNames: ["Te05", "Te0S", "Te09", "Te0H",
                                            "Tp01", "Tp05", "Tp09", "Tp0D",
                                            "Tp0V", "Tp0Y", "Tp0b", "Tp0e"])

    // SMC keys carrying GPU die temperatures on the base M4. An M4 Pro, Max
    // or Ultra reports through "Tg1U" and "Tg1k" instead.
    static let gpu = SensorGroup(keyNames: ["Tg0G", "Tg0H"])

    let keys: [SMCKey]

    init(keyNames: [String]) {
        keys = keyNames.map(SMCKey.init)
    }

    // Hottest and mean reading across the set, both nil when none of the
    // keys resolved — which is what a new SoC generation looks like from
    // here. One pass, hand-rolled rather than compactMap().max(), to keep
    // the hot path free of an intermediate array.
    //
    // The hottest die is what throttles; the mean is what the machine is
    // actually sitting at, and one core spiking moves the two apart.
    func summary(on connection: SMCConnection) -> (hottest: Float?, average: Float?) {
        var hottest: Float?
        var total: Float = 0
        var count: Float = 0

        for key in keys {
            guard let celsius = connection.temperature(of: key) else {
                continue
            }

            total += celsius
            count += 1

            if let current = hottest, current >= celsius {
                continue
            }

            hottest = celsius
        }

        guard count > 0 else {
            return (nil, nil)
        }

        return (hottest, total / count)
    }

    // Every key of the set that resolved, named, for the detail report's
    // per-sensor strip. The streaming path keeps `summary` instead: it wants
    // two numbers and has no use for the array they came from.
    func readings(on connection: SMCConnection) -> [SensorReading] {
        var readings: [SensorReading] = []

        for key in keys {
            guard let celsius = connection.temperature(of: key) else {
                continue
            }

            readings.append(SensorReading(key: key.name, celsius: celsius))
        }

        return readings
    }

    // The same two figures `summary` produces, over a set already read.
    static func summary(of readings: [SensorReading]) -> (hottest: Float?, average: Float?) {
        var hottest: Float?
        var total: Float = 0

        for reading in readings {
            total += reading.celsius

            if let current = hottest, current >= reading.celsius {
                continue
            }

            hottest = reading.celsius
        }

        guard !readings.isEmpty else {
            return (nil, nil)
        }

        return (hottest, total / Float(readings.count))
    }
}

// Watts the whole machine is drawing, off the one SMC key that carries it —
// the figure Stats labels "System Total". Verified against an eight-thread
// burn on this M4: 6.9W idle, 15.6W loaded. "PDTR" is the adapter side of
// the same reading and runs a couple of watts higher, charging and
// conversion losses included.
struct PowerSensor {
    private static let key = SMCKey("PSTR")

    // A reading outside this range is a key that stopped meaning watts, not
    // a machine drawing nothing. The upper bound clears the largest Mac
    // power adapter several times over.
    private static let plausibleWatts: ClosedRange<Float> = 0.1...1000.0

    static func watts(on connection: SMCConnection) -> Float? {
        guard let watts = connection.float(of: key),
              plausibleWatts.contains(watts) else {
            return nil
        }

        return watts
    }
}

// Swap in use, straight out of the same sysctl `sysctl -n vm.swapusage`
// prints. Read here rather than in the caller because Hammerspoon's
// hs.execute spawns a shell for it — 4ms of blocked main thread every
// refresh, against nothing measurable on this side of an already-running
// process.
struct SwapUsage {
    private static let name = "vm.swapusage"

    static func usedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride

        guard sysctlbyname(name, &usage, &size, nil, 0) == 0 else {
            return nil
        }

        return usage.xsu_used
    }
}

// Physical memory fitted to the machine. Constant for the life of the boot,
// but reported per call anyway: it costs one sysctl and saves the caller a
// second source of truth for what "total" means.
struct PhysicalMemory {
    private static let name = "hw.memsize"

    static func totalBytes() -> UInt64? {
        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.stride

        guard sysctlbyname(name, &total, &size, nil, 0) == 0 else {
            return nil
        }

        return total
    }
}

// Rendering for the one-line JSON both reports emit, by hand because this
// tool does not import Foundation and so has no JSONSerialization.
//
// null rather than a stand-in number throughout, so a caller can tell "not
// readable" from "cold" and show a placeholder instead of a lie.
enum JSON {
    private static let reportedDecimals = 1

    static func number(_ value: Float?) -> String {
        number(value, decimals: reportedDecimals)
    }

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

    // Sensor keys and interface names come from the kernel and could not
    // carry a quote if they tried, but a process is named after an
    // executable on disk and an executable may legally be named anything.
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

// What the menubar row itself needs and nothing more: four readings, small
// enough to stream every couple of seconds for the life of the session.
struct BarReport {
    let cpuCelsius: Float?
    let cpuAverageCelsius: Float?
    let watts: Float?
    let swapUsedBytes: UInt64?

    // One line per key, so adding a reading is one line and the name sits
    // next to the value it carries.
    var json: String {
        JSON.object([
            ("cpu", JSON.number(cpuCelsius)),
            ("cpu_avg", JSON.number(cpuAverageCelsius)),
            ("watts", JSON.number(watts)),
            ("swap_bytes", JSON.integer(swapUsedBytes)),
        ])
    }
}

// Everything a dropdown has room for, taken once when it opens. The two
// summary figures the bar also carries are repeated here rather than left to
// the caller to splice in: this report is a complete picture of the moment
// it was taken, and the streamed one is up to two seconds older.
struct DetailReport {
    let cpuSensors: [SensorReading]
    let gpuSensors: [SensorReading]
    let gpuUsagePercent: Int?
    let watts: Float?
    let swapUsedBytes: UInt64?
    let memoryTotalBytes: UInt64?

    private func sensors(_ readings: [SensorReading]) -> String {
        JSON.array(readings.map {
            JSON.object([("key", JSON.text($0.key)), ("c", JSON.number($0.celsius))])
        })
    }

    var json: String {
        let cpu = SensorGroup.summary(of: cpuSensors)
        let gpu = SensorGroup.summary(of: gpuSensors)

        return JSON.object([
            ("cpu", JSON.number(cpu.hottest)),
            ("cpu_avg", JSON.number(cpu.average)),
            ("cpu_sensors", sensors(cpuSensors)),
            ("gpu", JSON.number(gpu.hottest)),
            ("gpu_avg", JSON.number(gpu.average)),
            ("gpu_sensors", sensors(gpuSensors)),
            ("gpu_usage", JSON.integer(gpuUsagePercent)),
            ("watts", JSON.number(watts)),
            ("swap_bytes", JSON.integer(swapUsedBytes)),
            ("ram_total_bytes", JSON.integer(memoryTotalBytes)),
        ])
    }
}

// Entry point: pick the subcommand, open the SMC once, print, exit.
struct SensorTempsCommand {
    private static let toolName = "c-sensor-temps-macos"
    private static let listSubcommand = "list"
    private static let watchSubcommand = "watch"
    private static let detailsSubcommand = "details"
    private static let listedDecimals = 2

    // Which family of keys `list` walks when no prefix is given.
    private static let defaultListedPrefix = UInt8(ascii: "T")

    // Temperature and power move slowly enough that a second is generous.
    private static let defaultIntervalMilliseconds: UInt32 = 1000
    private static let microsecondsPerMillisecond: UInt32 = 1000

    let arguments: [String]

    private var wantsKeyListing: Bool {
        arguments.dropFirst().first == Self.listSubcommand
    }

    private var wantsWatch: Bool {
        arguments.dropFirst().first == Self.watchSubcommand
    }

    private var wantsDetails: Bool {
        arguments.dropFirst().first == Self.detailsSubcommand
    }

    private var intervalMilliseconds: UInt32 {
        guard let argument = arguments.dropFirst(2).first,
              let milliseconds = UInt32(argument), milliseconds > 0 else {
            return Self.defaultIntervalMilliseconds
        }

        return milliseconds
    }

    // `list P` walks the power keys instead of the temperature ones. Only the
    // first character counts, so `list power` works too.
    private var listedPrefix: UInt8 {
        guard let argument = arguments.dropFirst(2).first,
              let character = argument.utf8.first else {
            return Self.defaultListedPrefix
        }

        return character
    }

    // Write to stderr and stop — every failure here is unrecoverable.
    private func fail(_ message: String) -> Never {
        fputs("\(Self.toolName): \(message)\n", stderr)
        exit(1)
    }

    // Every readable key of one family with its current value, one per line.
    private func printKeyListing(on connection: SMCConnection) {
        guard let keys = connection.keys(withPrefix: listedPrefix) else {
            fail("cannot read the key table")
        }

        for key in keys {
            guard let value = connection.probedFloat(of: key) else {
                continue
            }

            print("\(key.name)\t\(DecimalText(value: value, decimals: Self.listedDecimals).text)")
        }
    }

    // One reading, printed. stdout is block-buffered once it is a pipe, so a
    // watching caller would see nothing for kilobytes at a time without the
    // flush.
    private func emit(on connection: SMCConnection) {
        let cpu = SensorGroup.cpu.summary(on: connection)
        let report = BarReport(cpuCelsius: cpu.hottest,
                               cpuAverageCelsius: cpu.average,
                               watts: PowerSensor.watts(on: connection),
                               swapUsedBytes: SwapUsage.usedBytes())

        print(report.json)
        fflush(stdout)
    }

    // The dropdown's reading. One shot only: every key of both sensor sets is
    // read separately for it, where the streamed report reduces each set to
    // two figures, and nothing here changes fast enough to be worth repeating
    // between two menu openings.
    private func emitDetails(on connection: SMCConnection) {
        let report = DetailReport(cpuSensors: SensorGroup.cpu.readings(on: connection),
                                  gpuSensors: SensorGroup.gpu.readings(on: connection),
                                  gpuUsagePercent: AcceleratorUsage.percent(),
                                  watts: PowerSensor.watts(on: connection),
                                  swapUsedBytes: SwapUsage.usedBytes(),
                                  memoryTotalBytes: PhysicalMemory.totalBytes())

        print(report.json)
        fflush(stdout)
    }

    func run() -> Never {
        guard let connection = SMCConnection() else {
            fail("cannot open AppleSMC")
        }

        if wantsKeyListing {
            printKeyListing(on: connection)
            exit(0)
        }

        if wantsDetails {
            emitDetails(on: connection)
            exit(0)
        }

        if !wantsWatch {
            emit(on: connection)
            exit(0)
        }

        // The SMC user client is opened once and reused for the life of the
        // process, which is most of what watching saves over re-invoking:
        // the connection and the Swift runtime both survive the interval.
        let interval = intervalMilliseconds * Self.microsecondsPerMillisecond

        while true {
            emit(on: connection)
            usleep(interval)
        }
    }
}

SensorTempsCommand(arguments: CommandLine.arguments).run()
