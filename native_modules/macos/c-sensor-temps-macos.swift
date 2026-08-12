// Read Apple Silicon CPU and GPU die temperatures from the SMC, report the
// hottest sensor in each group, and add the GPU's current utilisation and
// the whole machine's power draw.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the
// binary in ~/dotfiles/bin_native/macos/. The source lives in
// native_modules/ because it is compiled rather than interpreted; only the
// built artefact goes on PATH, and only on macOS.
//
//   c-sensor-temps-macos          {"cpu":47.9,"gpu":42.0,"gpu_usage":12,"watts":10.2}
//   c-sensor-temps-macos list     every readable T-prefixed sensor, one per line
//   c-sensor-temps-macos list P   the same for the P-prefixed power keys
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

// GPU load, straight out of the accelerator's own performance counters.
// The same numbers Activity Monitor's GPU history draws, and the only
// route to them: there is no SMC key for utilisation.
struct AcceleratorUsage {
    // Matching on the base class picks up whichever AGXAccelerator
    // subclass this SoC actually publishes.
    private static let serviceClass = "IOAccelerator"
    private static let statisticsProperty = "PerformanceStatistics"
    private static let utilizationKey = "Device Utilization %"

    private static func cfString(_ text: String) -> CFString {
        CFStringCreateWithCString(nil, text, CFStringBuiltInEncodings.UTF8.rawValue)
    }

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

// The readings the command reports, and their JSON rendering.
struct SensorReport {
    private static let reportedDecimals = 1

    let cpuCelsius: Float?
    let cpuAverageCelsius: Float?
    let gpuCelsius: Float?
    let gpuAverageCelsius: Float?
    let gpuUsagePercent: Int?
    let watts: Float?

    // null rather than a stand-in number, so a caller can tell "not
    // readable" from "cold" and show a placeholder instead of a lie.
    private func field(_ value: Float?) -> String {
        guard let value else {
            return "null"
        }

        return DecimalText(value: value, decimals: Self.reportedDecimals).text
    }

    private func field(_ percent: Int?) -> String {
        guard let percent else {
            return "null"
        }

        return "\(percent)"
    }

    var json: String {
        "{\"cpu\":\(field(cpuCelsius)),\"cpu_avg\":\(field(cpuAverageCelsius)),"
            + "\"gpu\":\(field(gpuCelsius)),\"gpu_avg\":\(field(gpuAverageCelsius)),"
            + "\"gpu_usage\":\(field(gpuUsagePercent)),\"watts\":\(field(watts))}"
    }
}

// Entry point: pick the subcommand, open the SMC once, print, exit.
struct SensorTempsCommand {
    private static let toolName = "c-sensor-temps-macos"
    private static let listSubcommand = "list"
    private static let listedDecimals = 2

    // Which family of keys `list` walks when no prefix is given.
    private static let defaultListedPrefix = UInt8(ascii: "T")

    let arguments: [String]

    private var wantsKeyListing: Bool {
        arguments.dropFirst().first == Self.listSubcommand
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

    func run() -> Never {
        guard let connection = SMCConnection() else {
            fail("cannot open AppleSMC")
        }

        if wantsKeyListing {
            printKeyListing(on: connection)
            exit(0)
        }

        let cpu = SensorGroup.cpu.summary(on: connection)
        let gpu = SensorGroup.gpu.summary(on: connection)
        let report = SensorReport(cpuCelsius: cpu.hottest,
                                  cpuAverageCelsius: cpu.average,
                                  gpuCelsius: gpu.hottest,
                                  gpuAverageCelsius: gpu.average,
                                  gpuUsagePercent: AcceleratorUsage.percent(),
                                  watts: PowerSensor.watts(on: connection))

        print(report.json)
        exit(0)
    }
}

SensorTempsCommand(arguments: CommandLine.arguments).run()
