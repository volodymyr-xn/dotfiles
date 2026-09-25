// Read Apple Silicon CPU and GPU die temperatures from the SMC, report the
// hottest and mean sensor in each group, and add the GPU's current
// utilisation, the whole machine's power draw, swap and physical memory,
// plus the byte counters of the interface the default route uses.
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
//   c-sensor-temps-macos menubar 2000 system network
//                                  own and draw the menubar items; see
//                                  StatsMenubar
//   c-sensor-temps-macos list      every readable T-prefixed sensor, one per line
//   c-sensor-temps-macos list P    the same for the P-prefixed power keys
//
// Two report shapes, because the two callers want opposite things. The
// default and `watch` carry only what the menubar rows can show — four
// sensor readings and the network counters, small enough to stream every
// couple of seconds forever. `details` is the one a dropdown asks for when
// it opens: every die sensor named separately, the GPU, and total memory.
// None of that is worth a kernel round-trip twice a second.
//
// The network counters used to live in c-net-counters-macos, streamed on a
// second of their own. They were folded back in so one line feeds both
// menubar items: every line a helper writes wakes Hammerspoon and costs a
// repaint, and the wake-up — not the reading — is most of what a tick costs,
// so two streams on separate cadences cost three wake-ups where one stream
// costs one. Processes, uptime and load average stay in
// c-process-stats-macos: the process table wants a far slower cadence and
// comes from a kernel interface this tool never touches.
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
// The `menubar` subcommand draws the stats menubar items itself, so
// Hammerspoon no longer repaints them: a paint there cost 3–7ms of its main
// thread every tick, most of it the cold wake-up. That subcommand needs
// AppKit, and so the whole file links it; the reporting path still formats
// its own decimals through DecimalText rather than String(format:), so the
// JSON the other subcommands print is unchanged.

import AppKit
import Darwin
import IOKit
import SystemConfiguration

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

// Byte counters for the interface the default route currently uses. The
// counters rather than rates: the caller diffs two lines across the interval
// it actually saw, which is the only figure that stays honest when a line is
// late. The same split the CPU tick counters use.
struct NetworkCounters {
    // The dynamic store key carrying the interface the IPv4 default route
    // points at. There is no sysctl for it; the routing table would have to
    // be parsed to answer the same question. Resolved per reading, so a dock
    // or a Wi-Fi switch moves the measurement with it.
    private static let globalIPv4Key = "State:/Network/Global/IPv4"
    private static let primaryInterfaceProperty = "PrimaryInterface"
    private static let storeName = "c-system-sensors-macos"

    // Long enough for any BSD interface name ("en0", "utun4", "bridge100").
    private static let nameLength = 32

    // Opened once and kept for the life of the process: `watch` reads it on
    // every tick, and the session with configd is the expensive part of the
    // lookup, not the key read.
    private let store = SCDynamicStoreCreate(nil, cfString(storeName), nil, nil)

    // Name of the interface the default route uses, or nil when nothing is
    // routed — an offline machine, or one with only a link-local address.
    private func primaryInterfaceName() -> String? {
        guard let store,
              let value = SCDynamicStoreCopyValue(store, cfString(Self.globalIPv4Key)),
              CFGetTypeID(value) == CFDictionaryGetTypeID() else {
            return nil
        }

        let global = unsafeBitCast(value, to: CFDictionary.self)
        let property = cfString(Self.primaryInterfaceProperty)

        // Unmanaged rather than unsafeBitCast: the key has to stay alive
        // across the lookup, and a bitcast hands ARC no reason to keep it.
        guard let rawName = CFDictionaryGetValue(global,
                                                 Unmanaged.passUnretained(property).toOpaque()) else {
            return nil
        }

        let name = Unmanaged<CFString>.fromOpaque(rawName).takeUnretainedValue()

        guard CFGetTypeID(name) == CFStringGetTypeID() else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: Self.nameLength)

        guard CFStringGetCString(name, &buffer, Self.nameLength,
                                 CFStringBuiltInEncodings.UTF8.rawValue) else {
            return nil
        }

        return String(cString: buffer)
    }

    // Byte counters for one interface, off its AF_LINK entry.
    //
    // These are 32-bit and wrap every 4GB — about half a minute of saturated
    // Ethernet. The wrap is the caller's problem, and a cheap one at this
    // cadence: an unsigned delta modulo 2^32 is exact as long as no more than
    // one wrap happens between two reads.
    //
    // The 64-bit counters are not reachable from here. NET_RT_IFLIST2 is
    // documented to carry if_data64, but on this macOS its messages hold the
    // same truncated values — a full scan of the interface's message finds
    // the low 32 bits and nothing wider — so the extra sysctl walk buys
    // nothing over getifaddrs.
    private static func bytes(onInterface name: String) -> (received: UInt64, sent: UInt64)? {
        var addresses: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&addresses) == 0 else {
            return nil
        }

        defer { freeifaddrs(addresses) }

        var pointer = addresses

        while let entry = pointer {
            let interface = entry.pointee

            if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               strcmp(interface.ifa_name, name) == 0,
               let payload = interface.ifa_data {
                let data = payload.assumingMemoryBound(to: if_data.self).pointee

                return (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
            }

            pointer = interface.ifa_next
        }

        return nil
    }

    // The primary interface's name and both counters, or nil when nothing is
    // routed.
    func current() -> (name: String, received: UInt64, sent: UInt64)? {
        guard let name = primaryInterfaceName(),
              let counters = Self.bytes(onInterface: name) else {
            return nil
        }

        return (name, counters.received, counters.sent)
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

// What the menubar rows need and nothing more: four sensor readings and the
// network counters, small enough to stream every couple of seconds for the
// life of the session.
struct BarReport {
    let cpuCelsius: Float?
    let cpuAverageCelsius: Float?
    let watts: Float?
    let swapUsedBytes: UInt64?
    let network: (name: String, received: UInt64, sent: UInt64)?

    // One line per key, so adding a reading is one line and the name sits
    // next to the value it carries. The network fields are null together when
    // nothing is routed, so a caller can tell "no route" from "no traffic".
    var json: String {
        JSON.object([
            ("cpu", JSON.number(cpuCelsius)),
            ("cpu_avg", JSON.number(cpuAverageCelsius)),
            ("watts", JSON.number(watts)),
            ("swap_bytes", JSON.integer(swapUsedBytes)),
            ("net_in", JSON.integer(network?.received)),
            ("net_out", JSON.integer(network?.sent)),
            ("net_interface", JSON.text(network?.name)),
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

    // Everything the report carries, read now. Shared by the one-shot
    // `details` subcommand and the menubar's click event.
    static func current(on connection: SMCConnection) -> DetailReport {
        DetailReport(cpuSensors: SensorGroup.cpu.readings(on: connection),
                     gpuSensors: SensorGroup.gpu.readings(on: connection),
                     gpuUsagePercent: AcceleratorUsage.percent(),
                     watts: PowerSensor.watts(on: connection),
                     swapUsedBytes: SwapUsage.usedBytes(),
                     memoryTotalBytes: PhysicalMemory.totalBytes())
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

// Per-core CPU load between two samples: the busiest core and the mean across
// all of them. One pegged core is what a single-threaded build looks like,
// and the mean alone hides it. The same tick counters hs.host.cpuUsageTicks()
// reads, diffed here so the menubar needs nothing from Hammerspoon.
final class CPULoadSampler {
    private let host = mach_host_self()
    private var previousTicks: [integer_t]?

    // Both nil on the first sample after a start or a reset: there is no
    // earlier sample to diff against.
    func usage() -> (busiest: Float?, mean: Float?) {
        var coreCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &coreCount, &info,
                                  &infoCount) == KERN_SUCCESS,
              let info else {
            return (nil, nil)
        }

        let ticks = Array(UnsafeBufferPointer(start: info, count: Int(infoCount)))
        let byteCount = Int(infoCount) * MemoryLayout<integer_t>.stride

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(byteCount))

        let previous = previousTicks
        previousTicks = ticks

        guard let previous, previous.count == ticks.count else {
            return (nil, nil)
        }

        let stride = Int(CPU_STATE_MAX)
        var busiest: Float?
        var total: Float = 0
        var counted: Float = 0

        for core in 0..<Int(coreCount) {
            let base = core * stride

            // Wrapping subtraction, because the counters are 32-bit and a
            // long-running core laps them.
            func delta(_ state: Int32) -> Float {
                let index = base + Int(state)

                return Float(UInt32(bitPattern: ticks[index]) &- UInt32(bitPattern: previous[index]))
            }

            let active = delta(CPU_STATE_USER) + delta(CPU_STATE_SYSTEM) + delta(CPU_STATE_NICE)
            let all = active + delta(CPU_STATE_IDLE)

            guard all > 0 else {
                continue
            }

            let percent = 100 * active / all
            total += percent
            counted += 1

            if let current = busiest, current >= percent {
                continue
            }

            busiest = percent
        }

        guard counted > 0 else {
            return (nil, nil)
        }

        return (busiest, total / counted)
    }

    // Forget the previous sample, so the next one starts a fresh span instead
    // of averaging over a pause.
    func reset() {
        previousTicks = nil
    }
}

// Memory in use the way the menubar counts it: app memory (anonymous pages
// that are not purgeable), wired, and what the compressor occupies. The same
// four vm_statistics64 fields hs.host.vmStat() exposes.
enum MemoryInUse {
    private static let host = mach_host_self()

    // Bytes in use right now, or nil when the kernel refuses the statistics.
    static func bytes() -> UInt64? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride
            / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let anonymous = UInt64(statistics.internal_page_count)
        let purgeable = UInt64(statistics.purgeable_count)
        let app = anonymous > purgeable ? anonymous - purgeable : 0
        let pages = app + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)

        return pages * UInt64(getpagesize())
    }
}

// Interface byte counters turned into upload and download rates. The
// counters only ever climb, so a rate is the delta between two readings over
// the time between them — measured rather than assumed, because a tick
// lands when the run loop gets to it.
final class NetworkRates {
    // The interface counters are 32-bit and wrap every 4GB. A delta modulo
    // that is exact as long as under one wrap happens between two readings,
    // which at two seconds means anything short of an 11Gbit/s link.
    private static let counterWrap: UInt64 = 1 << 32

    private var previous: (received: UInt64, sent: UInt64, nanoseconds: UInt64)?

    // Bytes moved between two readings, unwrapping one 32-bit wrap.
    private static func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : current + counterWrap - previous
    }

    // Bytes per second each way, both nil on the first reading after a start
    // or a reset.
    func rates(received: UInt64, sent: UInt64) -> (upload: Float?, download: Float?) {
        let now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        let last = previous
        previous = (received, sent, now)

        guard let last, now > last.nanoseconds else {
            return (nil, nil)
        }

        let seconds = Float(now - last.nanoseconds) / 1_000_000_000

        return (Float(Self.delta(sent, last.sent)) / seconds,
                Float(Self.delta(received, last.received)) / seconds)
    }

    // After a pause the gap can hold more than one wrap, and a delta across
    // it would be a rate that never happened.
    func reset() {
        previous = nil
    }
}

// A rolling window of power readings: what a burst actually cost is the mean
// of the last minute, not whatever the instant reading says.
final class PowerWindow {
    private let sampleLimit: Int
    private var samples: [Float] = []
    private var total: Float = 0

    // `sampleLimit` readings is the span: the caller knows its own cadence.
    init(sampleLimit: Int) {
        self.sampleLimit = max(sampleLimit, 1)
    }

    // A tick that could not read power leaves the window untouched rather
    // than recording a zero, which would drag the mean down.
    func record(_ watts: Float?) {
        guard let watts else {
            return
        }

        samples.append(watts)
        total += watts

        if samples.count > sampleLimit {
            total -= samples.removeFirst()
        }
    }

    // Mean of the window, nil until the first reading lands.
    var average: Float? {
        samples.isEmpty ? nil : total / Float(samples.count)
    }

    // Floor and ceiling of the same window: how spiky the stretch was.
    var range: (low: Float?, high: Float?) {
        (samples.min(), samples.max())
    }

    // Empty the window, so readings from before a pause do not linger.
    func reset() {
        samples = []
        total = 0
    }
}

// Everything one tick measured, computed once and shared by the two rows,
// the readings line and the plain-text mirrors.
struct MenubarReadings {
    let ramUsedBytes: UInt64?
    let swapUsedBytes: UInt64?
    let cpuBusiest: Float?
    let cpuMean: Float?
    let cpuCelsius: Float?
    let cpuAverageCelsius: Float?
    let watts: Float?
    let wattsAverage: Float?
    let wattsLow: Float?
    let wattsHigh: Float?
    let network: (name: String, received: UInt64, sent: UInt64)?
    let uploadRate: Float?
    let downloadRate: Float?
}

// The figures as the bar spells them, ported from hammerspoon/lib/stat_format
// so the two stay one vocabulary: the panels Hammerspoon still draws format
// their own figures with that file.
enum StatText {
    static let placeholder = "--"

    private static let bytesPerKilobyte: Float = 1024
    private static let bytesPerGigabyte: Float = 1024 * 1024 * 1024
    private static let rateUnits = ["B", "KB", "MB", "GB"]
    private static let sizeUnits = ["B", "K", "M", "G", "T"]

    // A decimal only below ten, so a column stays narrow while a small
    // figure still shows movement.
    private static let decimalBelow: Float = 10

    // Climb the unit ladder until the value fits, and report where it
    // stopped.
    private static func scaled(_ value: Float, units: [String]) -> (value: Float, unit: String, index: Int) {
        var remaining = value
        var index = 0

        while remaining >= bytesPerKilobyte && index < units.count - 1 {
            remaining /= bytesPerKilobyte
            index += 1
        }

        return (remaining, units[index], index)
    }

    // "45°" for a live reading.
    static func celsius(_ celsius: Float?) -> String {
        guard let celsius else {
            return placeholder + "°"
        }

        return String(format: "%.0f°", celsius)
    }

    // "12%" for a live figure.
    static func percent(_ percent: Float?) -> String {
        guard let percent else {
            return placeholder + "%"
        }

        return String(format: "%.0f%%", percent)
    }

    // "15GB": whole gigabytes, because the decimal was noise at a glance.
    static func gigabytes(_ bytes: UInt64?) -> String {
        guard let bytes else {
            return placeholder
        }

        return String(format: "%.0fGB", Float(bytes) / bytesPerGigabyte)
    }

    // "512M", "3G", "1.2T": the largest unit the size fills, no space.
    static func bytes(_ bytes: UInt64?) -> String {
        guard let bytes else {
            return placeholder
        }

        let size = scaled(Float(bytes), units: sizeUnits)
        let pattern = size.value < decimalBelow && size.index > 0 ? "%.1f%@" : "%.0f%@"

        return String(format: pattern, size.value, size.unit)
    }

    // "49 KB/s": the largest unit the rate fits in.
    static func rate(_ bytesPerSecond: Float?) -> String {
        guard let bytesPerSecond else {
            return placeholder + "/s"
        }

        let rate = scaled(bytesPerSecond, units: rateUnits)
        let pattern = rate.value < decimalBelow && rate.index > 0 ? "%.1f %@/s" : "%.0f %@/s"

        return String(format: pattern, rate.value, rate.unit)
    }

    // "18.1W": one decimal, because idle draw moves in tenths.
    static func watts(_ watts: Float?) -> String {
        guard let watts else {
            return placeholder + "W"
        }

        return String(format: "%.1fW", watts)
    }
}

// The colours the rows are drawn in, matching hammerspoon/lib/stat_panel: the
// resting text follows the system appearance, and a reading past its
// threshold turns orange, then red.
enum RowPalette {
    static let warning = NSColor(srgbRed: 1, green: 0.58, blue: 0, alpha: 1)
    static let critical = NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1)

    // White on a dark bar, black on a light one.
    static func resting() -> NSColor {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return dark ? .white : .black
    }

    // The warning colour a reading has earned, or `resting` below both marks.
    static func threshold(_ value: Float?, warnAt: Float, criticalAt: Float,
                          resting: NSColor) -> NSColor {
        guard let value else {
            return resting
        }

        if value >= criticalAt {
            return critical
        }

        return value >= warnAt ? warning : resting
    }
}

// The arrows that head the two throughput figures, drawn from the same paths
// as hammerspoon/assets/arrow_up.svg and arrow_down.svg (a 16-unit viewBox,
// stroked 2.2 wide with round ends).
enum ArrowIcon {
    case up
    case down

    private static let viewBox: CGFloat = 16
    private static let strokeWidth: CGFloat = 2.2

    // Polylines in viewBox units: the shaft, then the head.
    private var strokes: [[NSPoint]] {
        switch self {
        case .up:
            return [[NSPoint(x: 8, y: 13.5), NSPoint(x: 8, y: 3.4)],
                    [NSPoint(x: 3.4, y: 8), NSPoint(x: 8, y: 3.2), NSPoint(x: 12.6, y: 8)]]
        case .down:
            return [[NSPoint(x: 8, y: 2.5), NSPoint(x: 8, y: 12.6)],
                    [NSPoint(x: 3.4, y: 8), NSPoint(x: 8, y: 12.8), NSPoint(x: 12.6, y: 8)]]
        }
    }

    // Draw into `rect` of a flipped context, where y grows downwards the way
    // it does in the SVG.
    func draw(in rect: NSRect, color: NSColor) {
        let scale = rect.width / Self.viewBox
        let path = NSBezierPath()

        for stroke in strokes {
            for (index, point) in stroke.enumerated() {
                let placed = NSPoint(x: rect.minX + point.x * scale, y: rect.minY + point.y * scale)

                if index == 0 {
                    path.move(to: placed)
                } else {
                    path.line(to: placed)
                }
            }
        }

        path.lineWidth = Self.strokeWidth * scale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }
}

// One figure of a column: its text, colour and face, and the arrow that
// heads it when it has one.
struct RowBand {
    let text: String
    let color: NSColor
    var font: NSFont = MenubarRow.font
    var icon: ArrowIcon?
}

// A column of the row: one band spanning both rows, or two stacked. A
// reserved width is claimed whatever the column reads, with its figures
// right-aligned inside it, so a figure that swings several digits does not
// drag every item to its left sideways.
struct RowColumn {
    let top: RowBand
    var bottom: RowBand?
    var reservedWidth: CGFloat?
}

// The stacked-column row, ported from hammerspoon/lib/menubar_row: two rows
// of figures in the height of the bar, laid out left to right and handed to
// the status item as its image. Same faces, gaps and placement, so the move
// out of Hammerspoon does not show in the bar.
enum MenubarRow {
    static let barHeight: CGFloat = 22
    static let rowCount: CGFloat = 2
    static let columnGap: CGFloat = 10
    static let iconSize: CGFloat = barHeight / rowCount - 2
    static let iconTextGap: CGFloat = 2

    // Roughly the share of a line box the system font leaves below the
    // baseline. A figure spanning the whole bar comes down by it, so a
    // digits-only figure sits on the optical centre rather than the
    // geometric one.
    static let descenderShare: CGFloat = 0.09

    static let font = NSFont.systemFont(ofSize: 10)
    static let soloFont = NSFont.systemFont(ofSize: 13.9)
    static let soloBoldFont = NSFont.boldSystemFont(ofSize: 13.9)

    // Separators of the plain-text mirror only; on the bar the columns are
    // spaced in points.
    private static let valueSeparator = " "
    private static let columnSeparator = "  "

    private enum Element {
        case text(NSAttributedString, NSPoint)
        case icon(ArrowIcon, NSRect, NSColor)
    }

    // A band's text in its own face and colour.
    private static func styled(_ band: RowBand) -> NSAttributedString {
        NSAttributedString(string: band.text,
                           attributes: [.font: band.font, .foregroundColor: band.color])
    }

    // Width a column claims whatever it reads: its widest form, plus the icon
    // and the gap after it when the column carries one.
    static func reservedWidth(template: String, font: NSFont = font, withIcon: Bool) -> CGFloat {
        let width = NSAttributedString(string: template, attributes: [.font: font]).size().width

        return withIcon ? width + iconSize + iconTextGap : width
    }

    // Top edge for content starting at `row` and spanning `span` rows,
    // centred in the band it was given.
    private static func rowOrigin(row: CGFloat, span: CGFloat, height: CGFloat) -> CGFloat {
        let rowHeight = barHeight / rowCount
        let origin = row * rowHeight + (rowHeight * span - height) / 2

        return span > 1 ? origin + height * descenderShare : origin
    }

    // One band's elements, returning the width the pair claimed.
    private static func place(_ band: RowBand, x: CGFloat, row: CGFloat, span: CGFloat,
                              boxWidth: CGFloat?, into elements: inout [Element]) -> CGFloat {
        var textX = x
        var iconWidth: CGFloat = 0

        if let icon = band.icon {
            let y = rowOrigin(row: row, span: span, height: iconSize)

            elements.append(.icon(icon, NSRect(x: x, y: y, width: iconSize, height: iconSize), band.color))
            iconWidth = iconSize + iconTextGap
            textX = x + iconWidth
        }

        let text = styled(band)
        let size = text.size()

        if let boxWidth {
            textX = x + boxWidth - size.width
        }

        elements.append(.text(text, NSPoint(x: textX, y: rowOrigin(row: row, span: span, height: size.height))))

        return iconWidth + size.width
    }

    // The row as an image for a status item, and its plain-text mirror.
    static func render(_ columns: [RowColumn]) -> (image: NSImage, text: String) {
        var elements: [Element] = []
        var plainParts: [String] = []
        var x: CGFloat = 0

        for column in columns {
            var width: CGFloat
            var plain = column.top.text

            if let bottom = column.bottom {
                width = max(place(column.top, x: x, row: 0, span: 1, boxWidth: column.reservedWidth,
                                  into: &elements),
                            place(bottom, x: x, row: 1, span: 1, boxWidth: column.reservedWidth,
                                  into: &elements))
                plain += valueSeparator + bottom.text
            } else {
                width = place(column.top, x: x, row: 0, span: rowCount, boxWidth: column.reservedWidth,
                              into: &elements)
            }

            if let reserved = column.reservedWidth {
                width = max(width, reserved)
            }

            x += width + columnGap
            plainParts.append(plain)
        }

        let size = NSSize(width: max(x - columnGap, 1), height: barHeight)

        // Drawn lazily, at whatever backing scale the bar's screen has.
        let image = NSImage(size: size, flipped: true) { _ in
            for element in elements {
                switch element {
                case .text(let text, let point):
                    text.draw(at: point)
                case .icon(let icon, let rect, let color):
                    icon.draw(in: rect, color: color)
                }
            }

            return true
        }

        return (image, plainParts.joined(separator: columnSeparator))
    }
}

// Which of the two items a line or a click is about. The raw values are the
// names Hammerspoon passes on the command line and reads back in events.
enum MenubarItem: String, CaseIterable {
    case network
    case system
}

// The five system columns, left to right: memory in use, swap in use, busiest
// core over mean load, hottest die over the sensor mean, and current draw
// over the rolling mean. Only readings with a threshold take the warning
// colour.
enum SystemRow {
    private static let warnCelsius: Float = 75
    private static let criticalCelsius: Float = 92

    private static let bytesPerMegabyte: Float = 1024 * 1024
    private static let warnSwapBytes: Float = 200 * bytesPerMegabyte
    private static let criticalSwapBytes: Float = 3 * 1024 * bytesPerMegabyte
    private static let noSwapText = "No swap"

    // One temperature figure, tinted by how close it is to throttling.
    private static func celsius(_ value: Float?, resting: NSColor) -> RowBand {
        RowBand(text: StatText.celsius(value),
                color: RowPalette.threshold(value, warnAt: warnCelsius, criticalAt: criticalCelsius,
                                            resting: resting))
    }

    // Idle swap reads "No swap" rather than "0B": zero paging is a state, and
    // the word says so where a zeroed size looks like a stalled reading.
    private static func swap(_ bytes: UInt64?, resting: NSColor) -> RowBand {
        let color = RowPalette.threshold(bytes.map(Float.init), warnAt: warnSwapBytes,
                                         criticalAt: criticalSwapBytes, resting: resting)

        if bytes == 0 {
            return RowBand(text: noSwapText, color: color, font: MenubarRow.soloBoldFont)
        }

        return RowBand(text: StatText.bytes(bytes), color: color, font: MenubarRow.soloFont)
    }

    // The five columns for one tick's readings.
    static func columns(_ readings: MenubarReadings, resting: NSColor) -> [RowColumn] {
        [
            RowColumn(top: RowBand(text: StatText.gigabytes(readings.ramUsedBytes), color: resting,
                                   font: MenubarRow.soloFont)),
            RowColumn(top: swap(readings.swapUsedBytes, resting: resting)),
            RowColumn(top: RowBand(text: StatText.percent(readings.cpuBusiest), color: resting),
                      bottom: RowBand(text: StatText.percent(readings.cpuMean), color: resting)),
            RowColumn(top: celsius(readings.cpuCelsius, resting: resting),
                      bottom: celsius(readings.cpuAverageCelsius, resting: resting)),
            RowColumn(top: RowBand(text: StatText.watts(readings.watts), color: resting),
                      bottom: RowBand(text: StatText.watts(readings.wattsAverage), color: resting)),
        ]
    }
}

// The throughput column: upload over download, each headed by its arrow,
// reserved at the width of its widest reading.
enum NetworkRow {
    // Eights because they are the widest digit in a proportional face.
    private static let widthTemplate = "888 MB/s"

    private static let reservedWidth = MenubarRow.reservedWidth(template: widthTemplate, withIcon: true)

    // The one throughput column for one tick's readings.
    static func columns(_ readings: MenubarReadings, resting: NSColor) -> [RowColumn] {
        [
            RowColumn(top: RowBand(text: StatText.rate(readings.uploadRate), color: resting, icon: .up),
                      bottom: RowBand(text: StatText.rate(readings.downloadRate), color: resting,
                                      icon: .down),
                      reservedWidth: reservedWidth),
        ]
    }
}

// Why the bar is out of sight. Tracked separately because they overlap and
// clear in any order: the screens wake before the lock is gone.
enum AwayReason {
    case locked
    case screensAsleep
    case screensaver
}

// The `menubar` subcommand: owns the status items, samples and draws them on
// a timer, and tells Hammerspoon what happened as one JSON line per event —
// `readings` every tick, `click` when an item is clicked. Hammerspoon draws
// the panels behind the clicks and nothing else.
final class StatsMenubar: NSObject {
    // A minute of power history, whatever the tick.
    private static let powerWindowSeconds: Double = 60

    // Screen lock, unlock and screensaver arrive as distributed
    // notifications; there is no NSWorkspace equivalent.
    private static let awayNotifications: [(name: String, reason: AwayReason, away: Bool)] = [
        ("com.apple.screenIsLocked", .locked, true),
        ("com.apple.screenIsUnlocked", .locked, false),
        ("com.apple.screensaver.didstart", .screensaver, true),
        ("com.apple.screensaver.didstop", .screensaver, false),
    ]

    private let connection: SMCConnection
    private let interval: TimeInterval
    private let network = NetworkCounters()
    private let cpu = CPULoadSampler()
    private let rates = NetworkRates()
    private let power: PowerWindow
    private var items: [MenubarItem: NSStatusItem] = [:]
    private var timer: Timer?
    private var away = Set<AwayReason>()

    // Creates the requested status items; nothing ticks until `start`.
    init(connection: SMCConnection, intervalMilliseconds: UInt32, shown: [MenubarItem]) {
        self.connection = connection
        interval = TimeInterval(intervalMilliseconds) / 1000
        power = PowerWindow(sampleLimit: Int(Self.powerWindowSeconds / interval))

        super.init()

        // Created right to left: macOS puts each new item to the left of the
        // ones already there, so network lands to the right of system, the
        // order Hammerspoon had them in.
        for item in MenubarItem.allCases where shown.contains(item) {
            items[item] = makeStatusItem(item)
        }
    }

    // The autosave name keeps a ⌘-drag reorder across restarts. Visibility
    // persists under it too, so it is forced back on: showing and hiding is
    // Hammerspoon's call, made by which items it asks for.
    private func makeStatusItem(_ item: MenubarItem) -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "c-system-sensors-macos." + item.rawValue
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        return statusItem
    }

    // Begin: watch for the bar going out of sight and for EOF, then tick.
    func start() {
        observeAway()
        watchStandardInput()
        resume()
    }

    // One JSON object per line. stdout is block-buffered once it is a pipe,
    // so every line is flushed; a closed pipe raises SIGPIPE and ends the
    // process, which is what should happen when Hammerspoon is gone.
    private func emit(_ fields: [(name: String, value: String)]) {
        print(JSON.object(fields))
        fflush(stdout)
    }

    // Take one tick's readings from every source.
    private func sample() -> MenubarReadings {
        let temperatures = SensorGroup.cpu.summary(on: connection)
        let watts = PowerSensor.watts(on: connection)
        let load = cpu.usage()
        let counters = network.current()
        var upload: Float?
        var download: Float?

        if let counters {
            (upload, download) = rates.rates(received: counters.received, sent: counters.sent)
        }

        power.record(watts)

        let extremes = power.range

        return MenubarReadings(ramUsedBytes: MemoryInUse.bytes(),
                               swapUsedBytes: SwapUsage.usedBytes(),
                               cpuBusiest: load.busiest,
                               cpuMean: load.mean,
                               cpuCelsius: temperatures.hottest,
                               cpuAverageCelsius: temperatures.average,
                               watts: watts,
                               wattsAverage: power.average,
                               wattsLow: extremes.low,
                               wattsHigh: extremes.high,
                               network: counters,
                               uploadRate: upload,
                               downloadRate: download)
    }

    // Repaint each shown item and report the tick. The mirrors are what
    // Hammerspoon hands back from `title()`.
    @objc private func tick() {
        // Reparented to launchd means Hammerspoon died without closing the
        // pipe; nobody is left to read, and the items would linger.
        if getppid() == 1 {
            exit(0)
        }

        let readings = sample()
        let resting = RowPalette.resting()
        let systemText = paint(.system, SystemRow.columns(readings, resting: resting))
        let networkText = paint(.network, NetworkRow.columns(readings, resting: resting))

        emit([
            ("event", JSON.text("readings")),
            ("ram_used", JSON.integer(readings.ramUsedBytes)),
            ("swap_bytes", JSON.integer(readings.swapUsedBytes)),
            ("cpu_busiest", JSON.number(readings.cpuBusiest)),
            ("cpu_mean", JSON.number(readings.cpuMean)),
            ("cpu", JSON.number(readings.cpuCelsius)),
            ("cpu_avg", JSON.number(readings.cpuAverageCelsius)),
            ("watts", JSON.number(readings.watts)),
            ("watts_avg", JSON.number(readings.wattsAverage)),
            ("watts_low", JSON.number(readings.wattsLow)),
            ("watts_high", JSON.number(readings.wattsHigh)),
            ("net_in", JSON.integer(readings.network?.received)),
            ("net_out", JSON.integer(readings.network?.sent)),
            ("net_interface", JSON.text(readings.network?.name)),
            ("up_rate", JSON.number(readings.uploadRate, decimals: 0)),
            ("down_rate", JSON.number(readings.downloadRate, decimals: 0)),
            ("system_text", JSON.text(systemText)),
            ("network_text", JSON.text(networkText)),
        ])
    }

    // Draw one item's row, or nothing when Hammerspoon did not ask for the
    // item. Returns the plain-text mirror, nil for a hidden item.
    private func paint(_ item: MenubarItem, _ columns: [RowColumn]) -> String? {
        guard let button = items[item]?.button else {
            return nil
        }

        let row = MenubarRow.render(columns)
        button.image = row.image

        return row.text
    }

    // The clicked item's frame in Hammerspoon's coordinates — origin at the
    // top left of the primary screen, y growing downwards — so a panel can
    // hang under it. The system click carries the full details report too,
    // so its menu is built without another process.
    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let item = items.first(where: { $0.value.button === sender })?.key,
              let frame = sender.window?.frame else {
            return
        }

        // Whole points: a frame on a screen left of or above the primary one
        // is negative, which DecimalText does not spell.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let bounds = JSON.object([
            ("x", JSON.integer(Int(frame.minX.rounded()))),
            ("y", JSON.integer(Int((primaryHeight - frame.maxY).rounded()))),
            ("w", JSON.integer(Int(frame.width.rounded()))),
            ("h", JSON.integer(Int(frame.height.rounded()))),
        ])
        var fields: [(name: String, value: String)] = [
            ("event", JSON.text("click")),
            ("item", JSON.text(item.rawValue)),
            ("frame", bounds),
        ]

        if item == .system {
            fields.append(("details", DetailReport.current(on: connection).json))
        }

        emit(fields)
    }

    // Start ticking from fresh baselines: whatever was measured before a
    // pause would otherwise turn into a rate or an average across it.
    private func resume() {
        guard timer == nil else {
            return
        }

        cpu.reset()
        rates.reset()
        power.reset()
        tick()

        let timer = Timer(timeInterval: interval, target: self, selector: #selector(tick),
                          userInfo: nil, repeats: true)

        // Slack for the system to coalesce the wake-up with others.
        timer.tolerance = interval / 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // Stop ticking until the bar is back in sight.
    private func pause() {
        timer?.invalidate()
        timer = nil
    }

    // Record one cause of the bar being out of sight, or its end.
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

    // Stop ticking while nobody can see the bar: screens locked, asleep, or
    // behind the screensaver.
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

    // Commands from Hammerspoon, one per line: `lock` and `unlock` rehearse
    // the screen lock without locking anything. EOF means Hammerspoon is
    // gone, and the items go with it. Only watched when stdin is a pipe — a
    // terminal or /dev/null would read as EOF at once.
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

// Entry point: pick the subcommand, open the SMC once, print, exit.
struct SensorTempsCommand {
    private static let toolName = "c-sensor-temps-macos"
    private static let listSubcommand = "list"
    private static let watchSubcommand = "watch"
    private static let detailsSubcommand = "details"
    private static let menubarSubcommand = "menubar"
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

    // `menubar <ms> <items…>`: own and draw the status items.
    private var wantsMenubar: Bool {
        arguments.dropFirst().first == Self.menubarSubcommand
    }

    // `menubar <ms> system network`: the items to show follow the interval.
    // Unknown names are ignored rather than fatal, so a caller newer than
    // the binary still gets the items both know.
    private var menubarItems: [MenubarItem] {
        arguments.dropFirst(3).compactMap(MenubarItem.init(rawValue:))
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
    private func emit(on connection: SMCConnection, network: NetworkCounters) {
        let cpu = SensorGroup.cpu.summary(on: connection)
        let report = BarReport(cpuCelsius: cpu.hottest,
                               cpuAverageCelsius: cpu.average,
                               watts: PowerSensor.watts(on: connection),
                               swapUsedBytes: SwapUsage.usedBytes(),
                               network: network.current())

        print(report.json)
        fflush(stdout)
    }

    // The dropdown's reading. One shot only: every key of both sensor sets is
    // read separately for it, where the streamed report reduces each set to
    // two figures, and nothing here changes fast enough to be worth repeating
    // between two menu openings.
    private func emitDetails(on connection: SMCConnection) {
        print(DetailReport.current(on: connection).json)
        fflush(stdout)
    }

    // An accessory app — status items, no Dock icon, no menu of its own —
    // running until Hammerspoon closes the pipe.
    private func runMenubar(on connection: SMCConnection) -> Never {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let menubar = StatsMenubar(connection: connection,
                                   intervalMilliseconds: intervalMilliseconds,
                                   shown: menubarItems)

        menubar.start()

        withExtendedLifetime(menubar) {
            application.run()
        }

        exit(0)
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

        if wantsMenubar {
            runMenubar(on: connection)
        }

        let network = NetworkCounters()

        if !wantsWatch {
            emit(on: connection, network: network)
            exit(0)
        }

        // The SMC user client and the configd session are opened once and
        // reused for the life of the process, which is most of what watching
        // saves over re-invoking: both connections and the Swift runtime
        // survive the interval.
        let interval = intervalMilliseconds * Self.microsecondsPerMillisecond

        while true {
            emit(on: connection, network: network)
            usleep(interval)
        }
    }
}

SensorTempsCommand(arguments: CommandLine.arguments).run()
