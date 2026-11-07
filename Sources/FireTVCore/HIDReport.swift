import Foundation

// MARK: - Legacy A1–A4 parser (kept verbatim in behaviour; covered by the original 22 tests)

public let targetReportID: UInt8 = 0xEF
public let legacyButtonMap: [UInt8: String] = [0xA1: "FireTV-A1", 0xA2: "FireTV-A2", 0xA3: "FireTV-A3", 0xA4: "FireTV-A4"]

public enum ParsedReport: Equatable {
    case ignored, released
    case button(UInt8)
    case unknown(UInt8)
}

public func parseReport(reportID: UInt8, bytes: [UInt8]) -> ParsedReport {
    guard reportID == targetReportID, !bytes.isEmpty else { return .ignored }
    var payload = bytes[...]
    if payload.first == targetReportID { payload = payload.dropFirst() }
    guard let code = payload.first else { return .ignored }
    if code == 0x00 { return .released }
    if legacyButtonMap[code] != nil { return .button(code) }
    return .unknown(code)
}

public final class PressTracker {
    public private(set) var current: UInt8 = 0
    public init() {}
    public func feed(_ parsed: ParsedReport) -> UInt8? {
        switch parsed {
        case .released, .ignored:
            if case .released = parsed { current = 0 }
            return nil
        case .unknown: return nil
        case .button(let code):
            if code == current { return nil }
            current = code
            return code
        }
    }
}

// MARK: - Generic report decoding (all report IDs)

/// One decoded input report: the full set of buttons currently down on that report ID.
/// The remote sends N-key arrays (consumer: up to two 16-bit usages, e.g. `ea 00 e9 00` while
/// volume− is held and volume+ is pressed), so a report is a *state*, not a single key.
public enum RemoteEvent: Equatable {
    case ignored
    case state(reportID: UInt8, pressed: [ButtonCode])
}

/// Accepts both buffer layouts (with or without the leading report-ID byte).
public func decodeReport(reportID: UInt8, bytes: [UInt8]) -> RemoteEvent {
    guard !bytes.isEmpty else { return .ignored }
    var payload = Array(bytes[...])
    if payload.first == reportID { payload.removeFirst() }
    guard !payload.isEmpty else { return .ignored }
    var codes: [ButtonCode] = []
    switch reportID {
    case ButtonTable.consumerReport:
        var i = 0
        while i < payload.count {
            let lo = UInt16(payload[i]); let hi = i + 1 < payload.count ? UInt16(payload[i + 1]) : 0
            let u = lo | (hi << 8)
            if u != 0 { codes.append(ButtonCode(reportID: reportID, code: u)) }
            i += 2
        }
    case ButtonTable.keyboardReport:
        for b in payload where b != 0 { codes.append(ButtonCode(reportID: reportID, code: UInt16(b))) }
    case ButtonTable.vendorReport:
        if let f = payload.first, f != 0 { codes.append(ButtonCode(reportID: reportID, code: UInt16(f))) }
    default:
        return .ignored
    }
    return .state(reportID: reportID, pressed: codes)
}

/// Turns report states into button press/release transitions by diffing against the held set.
public final class ButtonStateTracker {
    public private(set) var held: [UInt8: [ButtonCode]] = [:]
    public init() {}

    public enum Transition: Equatable { case press(ButtonCode), release(ButtonCode) }

    public func feed(_ e: RemoteEvent) -> [Transition] {
        guard case .state(let rid, let now) = e else { return [] }
        let before = held[rid] ?? []
        var out: [Transition] = []
        for c in before where !now.contains(c) { out.append(.release(c)) }
        for c in now where !before.contains(c) { out.append(.press(c)) }
        if now.isEmpty { held.removeValue(forKey: rid) } else { held[rid] = now }
        return out
    }
    public func reset() -> [Transition] {
        let out = held.values.flatMap { $0 }.map { Transition.release($0) }
        held = [:]
        return out
    }
}
