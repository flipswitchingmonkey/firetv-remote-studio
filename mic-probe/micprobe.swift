// micprobe — Fire TV remote microphone capture probe (push-to-talk).
// Opens the remote non-exclusively, watches the consumer report for the mic key (0x0221),
// sends OUTPUT report 0xF2 = 01/00 to start/stop audio, and records INPUT report 0xF0 packets.
// Usage: ./micprobe [outdir]     Ctrl+C to quit.
import Foundation
import IOKit.hid

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "captures"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
func ts() -> String { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date()) }
func log(_ s: String) { print("[\(ts())] \(s)"); fflush(stdout) }
func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined(separator: " ") }
func ioerr(_ r: IOReturn) -> String { String(format: "0x%08x", UInt32(bitPattern: r)) }

var device: IOHIDDevice?
var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
var micDown = false
var enabled = false
var segment = 0
var segFile: FileHandle?
var segStart = Date()
var segPackets = 0
var segBytes = 0
var segLengths: [Int: Int] = [:]
var segTOC: Set<UInt8> = []
var lastPacketTime = Date()
var totalReports: [UInt8: Int] = [:]

func setEnable(_ on: Bool) {
    guard let d = device else { return }
    // IOHIDDeviceSetReport: report ID is passed separately; the buffer holds only the payload.
    var payload: [UInt8] = [on ? 0x01 : 0x00]
    let r = IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0xF2, &payload, payload.count)
    log("SetReport(Output, id=0xF2, [\(hex(payload))]) -> \(ioerr(r)) \(r == kIOReturnSuccess ? "OK" : "FAILED")")
    if r != kIOReturnSuccess {
        // Fallback attempt: buffer with the report ID prepended (some stacks expect it).
        var withID: [UInt8] = [0xF2, on ? 0x01 : 0x00]
        let r2 = IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, 0xF2, &withID, withID.count)
        log("  retry with ID in buffer -> \(ioerr(r2)) \(r2 == kIOReturnSuccess ? "OK" : "FAILED")")
        enabled = (r2 == kIOReturnSuccess) && on
    } else { enabled = on }
}

func openSegment() {
    segment += 1
    let path = "\(outDir)/segment-\(segment).opuspkts"
    FileManager.default.createFile(atPath: path, contents: nil)
    segFile = FileHandle(forWritingAtPath: path)
    segStart = Date(); segPackets = 0; segBytes = 0; segLengths = [:]; segTOC = []
    log("segment \(segment) started -> \(path)")
}
func closeSegment() {
    guard let f = segFile else { return }
    try? f.close(); segFile = nil
    let dur = Date().timeIntervalSince(segStart)
    let rate = dur > 0 ? Double(segPackets) / dur : 0
    log(String(format: "segment %d closed: %d packets, %d bytes, %.2fs, %.1f pkt/s, lengths=%@, TOC=%@",
               segment, segPackets, segBytes, dur, rate,
               segLengths.map { "\($0.key)x\($0.value)" }.sorted().joined(separator: ",") as NSString,
               segTOC.map { String(format: "0x%02x", $0) }.sorted().joined(separator: ",") as NSString))
}

let inputCallback: IOHIDReportCallback = { _, result, _, type, reportID, report, length in
    guard result == kIOReturnSuccess, length > 0 else { return }
    let bytes = Array(UnsafeBufferPointer(start: report, count: Int(length)))
    let rid = UInt8(truncatingIfNeeded: reportID)
    totalReports[rid, default: 0] += 1
    var payload = bytes[...]
    if payload.first == rid { payload = payload.dropFirst() }
    switch rid {
    case 0xF0:
        let p = Array(payload)
        if segFile == nil { log("0xF0 audio packet while no segment open (len \(p.count))"); return }
        var len = UInt32(p.count)
        segFile?.write(Data(bytes: &len, count: 4)); segFile?.write(Data(p))
        segPackets += 1; segBytes += p.count; segLengths[p.count, default: 0] += 1
        if let t = p.first { segTOC.insert(t) }
        lastPacketTime = Date()
        if segPackets == 1 { log("first audio packet: len=\(p.count) toc=\(String(format: "0x%02x", p[0])) data=\(hex(Array(p.prefix(12))))…") }
        else if segPackets % 50 == 0 { log("… \(segPackets) packets") }
    case 0x02:
        let p = Array(payload)
        var usages: [UInt16] = []
        var i = 0
        while i + 1 < p.count { let u = UInt16(p[i]) | (UInt16(p[i + 1]) << 8); if u != 0 { usages.append(u) }; i += 2 }
        let mic = usages.contains(0x0221)
        if mic && !micDown {
            micDown = true
            log("MIC PRESSED (consumer 0x0221) raw=\(hex(bytes))")
            openSegment()
            setEnable(true)
        } else if !mic && micDown {
            micDown = false
            log("MIC RELEASED raw=\(hex(bytes))")
            setEnable(false)
            closeSegment()
        }
    case 0xF1, 0xF3:
        log("report 0x\(String(format: "%02x", rid)) (\(bytes.count) bytes): \(hex(bytes))")
    default:
        if ["0xef", "0x01"].contains(String(format: "0x%02x", rid)) { log("report 0x\(String(format: "%02x", rid)): \(hex(bytes))") }
    }
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x171, kIOHIDProductIDKey: 0x42f] as CFDictionary)
IOHIDManagerRegisterDeviceMatchingCallback(manager, { _, _, _, d in
    let r = IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
    log("device matched; open -> \(ioerr(r)) \(r == kIOReturnSuccess ? "OK" : "FAILED (is the app's exclusive helper or Karabiner holding it?)")")
    guard r == kIOReturnSuccess else { return }
    device = d
    IOHIDDeviceRegisterInputReportCallback(d, buffer, 256, inputCallback, nil)
    log("listening. Press and hold the mic button on the remote, speak, release. Ctrl+C to quit.")
}, nil)
IOHIDManagerRegisterDeviceRemovalCallback(manager, { _, _, _, _ in log("device removed"); device = nil }, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

signal(SIGINT, SIG_IGN)
let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sig.setEventHandler {
    if enabled { setEnable(false) }
    closeSegment()
    log("report counts: \(totalReports.map { String(format: "0x%02x=%d", $0.key, $0.value) }.sorted().joined(separator: " "))")
    if let d = device { IOHIDDeviceClose(d, IOOptionBits(kIOHIDOptionsTypeNone)) }
    exit(0)
}
sig.resume()
log("micprobe starting; output dir: \(outDir)")
CFRunLoopRun()
