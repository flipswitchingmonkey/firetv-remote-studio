import Foundation
import IOKit
import IOKit.hid

/// Owns the IOHIDManager for the Amazon Remote. Exactly one instance per process;
/// the GUI app is the only process that should run it (opening the device twice
/// from two processes is refused by IOKit anyway).
public final class HIDMonitor {
    public static let vendorID = 0x0171
    public static let productID = 0x042F

    public enum Status: Equatable {
        case stopped
        case waitingForDevice
        case connected(name: String)
        case blocked(String)   // device present but cannot be opened; retrying
    }
    public enum Event: Equatable {
        case status(Status)
        case report(reportID: UInt8, bytes: [UInt8])
        case log(String)
    }

    public var onEvent: (Event) -> Void = { _ in }
    public private(set) var status: Status = .stopped { didSet { if status != oldValue { onEvent(.status(status)) } } }
    public private(set) var isRunning = false

    private var manager: IOHIDManager?
    private var buffers: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]
    private var pending = Set<IOHIDDevice>()
    private var opened = Set<IOHIDDevice>()
    private var retry: DispatchSourceTimer?
    private let bufferSize = 256   // 0xF0 audio reports are 81 bytes

    public init() {}

    /// Input Monitoring (TCC) state for this process.
    public static var hasInputMonitoringAccess: Bool { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted }
    /// Shows the macOS prompt that adds this app to Privacy & Security > Input Monitoring.
    @discardableResult public static func requestInputMonitoringAccess() -> Bool { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }

    public func start() {
        guard !isRunning else { return }
        if !Self.hasInputMonitoringAccess {
            onEvent(.log("入力監視の権限がありません — システムの許可ダイアログを要求します"))
            Self.requestInputMonitoringAccess()
        }
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: Self.vendorID, kIOHIDProductIDKey: Self.productID] as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(m, { ctx, _, _, dev in
            Unmanaged<HIDMonitor>.fromOpaque(ctx!).takeUnretainedValue().deviceMatched(dev)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(m, { ctx, _, _, dev in
            Unmanaged<HIDMonitor>.fromOpaque(ctx!).takeUnretainedValue().deviceRemoved(dev)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        manager = m
        isRunning = true
        status = .waitingForDevice
        onEvent(.log("監視開始 (vid 0x171 / pid 0x42f)"))
    }

    public func stop() {
        guard isRunning, let m = manager else { return }
        retry?.cancel(); retry = nil
        for d in opened { IOHIDDeviceClose(d, IOOptionBits(kIOHIDOptionsTypeNone)) }
        for (_, b) in buffers { b.deallocate() }
        opened = []; buffers = [:]; pending = []
        IOHIDManagerUnscheduleFromRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = nil
        isRunning = false
        status = .stopped
        onEvent(.log("監視停止"))
    }

    /// OUTPUT report to the open device (non-exclusive mode). Buffer must begin with the report ID on macOS BLE HID.
    public func setOutputReport(id: UInt8, data: [UInt8]) -> IOReturn {
        guard let d = opened.first else { return kIOReturnNoDevice }
        var bytes = data
        if bytes.first != id { bytes.insert(id, at: 0) }
        return bytes.withUnsafeMutableBufferPointer { IOHIDDeviceSetReport(d, kIOHIDReportTypeOutput, CFIndex(id), $0.baseAddress!, $0.count) }
    }

    private func name(_ d: IOHIDDevice) -> String { (IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String) ?? "Amazon Remote" }

    private func deviceMatched(_ d: IOHIDDevice) {
        onEvent(.log("接続: \(name(d))"))
        pending.insert(d)
        if !tryOpen(d) { scheduleRetry() }
    }

    private func deviceRemoved(_ d: IOHIDDevice) {
        buffers.removeValue(forKey: d)?.deallocate()
        opened.remove(d); pending.remove(d)
        onEvent(.log("切断: \(name(d))"))
        status = .waitingForDevice
    }

    @discardableResult
    private func tryOpen(_ d: IOHIDDevice) -> Bool {
        if opened.contains(d) { return true }
        let r = IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))
        switch r {
        case kIOReturnSuccess:
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            buffers[d] = buf
            let ctx = Unmanaged.passUnretained(self).toOpaque()
            IOHIDDeviceRegisterInputReportCallback(d, buf, bufferSize, { ctx, result, _, _, reportID, report, length in
                guard result == kIOReturnSuccess, length > 0 else { return }
                let bytes = Array(UnsafeBufferPointer(start: report, count: Int(length)))
                Unmanaged<HIDMonitor>.fromOpaque(ctx!).takeUnretainedValue()
                    .onEvent(.report(reportID: UInt8(truncatingIfNeeded: reportID), bytes: bytes))
            }, ctx)
            opened.insert(d)
            status = .connected(name: name(d))
            onEvent(.log("デバイスを開きました: \(name(d))"))
            return true
        case kIOReturnExclusiveAccess:
            status = .blocked("別のプロセスがリモコンを専有しています（Karabiner-Elements の Devices で Amazon Remote の Modify events をオフにするか、旧CLIを終了してください）")
        case kIOReturnNotPermitted:
            status = .blocked("入力監視の権限がありません。システム設定 > プライバシーとセキュリティ > 入力監視 でこのアプリを許可してください")
        default:
            status = .blocked(String(format: "デバイスを開けません (0x%08x)", UInt32(bitPattern: r)))
        }
        return false
    }

    private func scheduleRetry() {
        if retry != nil { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 3, repeating: 3)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            let todo = self.pending.filter { !self.opened.contains($0) }
            if todo.isEmpty { self.retry?.cancel(); self.retry = nil; return }
            for d in todo where self.tryOpen(d) { self.onEvent(.log("デバイスが利用可能になりました")) }
        }
        t.resume(); retry = t
    }
}
