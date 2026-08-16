// Byte counters for the interface the default route currently uses, as one
// JSON line.
//
// Build with `dotfiles_setup/build_native_modules.sh`, which drops the binary
// in ~/dotfiles/bin_native/macos/.
//
//   c-net-counters-macos              {"in":4206020608,"out":882100224,"interface":"en0"}
//   c-net-counters-macos watch        a line every 500ms until killed
//   c-net-counters-macos watch 250    the same at another interval
//
// Split out of c-sensor-temps-macos because throughput wants a faster
// cadence than temperature does: half a second here against a second there,
// and a rate is only as good as the interval it was measured over.
//
// Counters rather than rates: the caller diffs two lines across the interval
// it actually saw, which is the only figure that stays honest when a line is
// late. The same split the CPU tick counters use.
//
// Foundation is deliberately not imported: Darwin and SystemConfiguration
// cover everything here.

import Darwin
import SystemConfiguration

// A CFString for a literal, built the Core Foundation way because this tool
// does not import Foundation and so has no String bridging.
func cfString(_ text: String) -> CFString {
    CFStringCreateWithCString(nil, text, CFStringBuiltInEncodings.UTF8.rawValue)
}

struct NetworkCounters {
    // The dynamic store key carrying the interface the IPv4 default route
    // points at. There is no sysctl for it; the routing table would have to
    // be parsed to answer the same question. Resolved per reading, so a dock
    // or a Wi-Fi switch moves the measurement with it.
    private static let globalIPv4Key = "State:/Network/Global/IPv4"
    private static let primaryInterfaceProperty = "PrimaryInterface"
    private static let storeName = "c-net-counters-macos"

    // Long enough for any BSD interface name ("en0", "utun4", "bridge100").
    private static let nameLength = 32

    // Name of the interface the default route uses, or nil when nothing is
    // routed — an offline machine, or one with only a link-local address.
    private static func primaryInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, cfString(storeName), nil, nil),
              let value = SCDynamicStoreCopyValue(store, cfString(globalIPv4Key)),
              CFGetTypeID(value) == CFDictionaryGetTypeID() else {
            return nil
        }

        let global = unsafeBitCast(value, to: CFDictionary.self)
        let property = cfString(primaryInterfaceProperty)

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

        var buffer = [CChar](repeating: 0, count: nameLength)

        guard CFStringGetCString(name, &buffer, nameLength,
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

    static func current() -> (name: String, received: UInt64, sent: UInt64)? {
        guard let name = primaryInterfaceName(),
              let counters = bytes(onInterface: name) else {
            return nil
        }

        return (name, counters.received, counters.sent)
    }
}

// One reading and its JSON rendering. null rather than a stand-in number, so
// a caller can tell "no route" from "no traffic".
struct CounterReport {
    let counters: (name: String, received: UInt64, sent: UInt64)?

    var json: String {
        guard let counters else {
            return #"{"in":null,"out":null,"interface":null}"#
        }

        // Interface names come from the kernel and cannot contain a quote or
        // a backslash, so they need no escaping beyond the quotes themselves.
        return #"{"in":\#(counters.received),"out":\#(counters.sent),"interface":"\#(counters.name)"}"#
    }
}

// Entry point: one line and exit, or a line per interval until killed.
struct NetCountersCommand {
    private static let watchSubcommand = "watch"
    private static let defaultIntervalMilliseconds: UInt32 = 500
    private static let microsecondsPerMillisecond: UInt32 = 1000

    let arguments: [String]

    private var wantsWatch: Bool {
        arguments.dropFirst().first == Self.watchSubcommand
    }

    private var intervalMilliseconds: UInt32 {
        guard let argument = arguments.dropFirst(2).first,
              let milliseconds = UInt32(argument), milliseconds > 0 else {
            return Self.defaultIntervalMilliseconds
        }

        return milliseconds
    }

    // stdout is block-buffered once it is a pipe, so a watching caller would
    // see nothing for kilobytes at a time without the flush.
    private func emit() {
        print(CounterReport(counters: NetworkCounters.current()).json)
        fflush(stdout)
    }

    func run() -> Never {
        if !wantsWatch {
            emit()
            exit(0)
        }

        let interval = intervalMilliseconds * Self.microsecondsPerMillisecond

        while true {
            emit()
            usleep(interval)
        }
    }
}

NetCountersCommand(arguments: CommandLine.arguments).run()
