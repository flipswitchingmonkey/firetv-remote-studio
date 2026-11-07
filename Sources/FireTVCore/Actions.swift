import Foundation

public struct KeyCombo: Codable, Hashable {
    public var keyCode: UInt16          // macOS virtual key code
    public var keyName: String          // display name, e.g. "C"
    public var command = false, shift = false, option = false, control = false
    public init(keyCode: UInt16, keyName: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.keyCode = keyCode; self.keyName = keyName
        self.command = command; self.shift = shift; self.option = option; self.control = control
    }
    public var display: String {
        var s = ""
        if control { s += "⌃" }; if option { s += "⌥" }; if shift { s += "⇧" }; if command { s += "⌘" }
        return s + keyName
    }
}

public enum MediaKey: String, Codable, CaseIterable, Hashable {
    case playPause, next, previous, fastForward, rewind, volumeUp, volumeDown, mute
    public var displayName: String {
        switch self {
        case .playPause: return "再生/一時停止"
        case .next: return "次へ"
        case .previous: return "前へ"
        case .fastForward: return "早送り"
        case .rewind: return "巻き戻し"
        case .volumeUp: return "音量+"
        case .volumeDown: return "音量−"
        case .mute: return "ミュート"
        }
    }
    /// NX_KEYTYPE_* values from IOKit/hidsystem/ev_keymap.h
    public var nxKeyType: Int32 {
        switch self {
        case .volumeUp: return 0
        case .volumeDown: return 1
        case .mute: return 7
        case .playPause: return 16
        case .next: return 17
        case .previous: return 18
        case .fastForward: return 19
        case .rewind: return 20
        }
    }
}

public enum LayerOp: Codable, Hashable {
    case momentary(Int)   // MO(n)
    case toggle(Int)      // TG(n)
    case switchTo(Int)    // TO(n)
    case setDefault(Int)  // DF(n)
    public var layer: Int {
        switch self { case .momentary(let n), .toggle(let n), .switchTo(let n), .setDefault(let n): return n }
    }
    public var display: String {
        switch self {
        case .momentary(let n): return "MO(\(n))"
        case .toggle(let n): return "TG(\(n))"
        case .switchTo(let n): return "TO(\(n))"
        case .setDefault(let n): return "DF(\(n))"
        }
    }
}

public struct MacroStep: Codable, Hashable, Identifiable {
    public var id: UUID
    public var action: Action
    public var delayMs: Int      // delay *after* this step
    public init(id: UUID = UUID(), action: Action, delayMs: Int = 0) { self.id = id; self.action = action; self.delayMs = delayMs }
}

public struct Macro: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var steps: [MacroStep]
    public init(id: UUID = UUID(), name: String, steps: [MacroStep] = []) { self.id = id; self.name = name; self.steps = steps }
}

/// What a button does. `transparent` falls through to lower layers; `none` stops.
public indirect enum Action: Codable, Hashable {
    case none
    case transparent
    /// Keep the button's original (macOS default) behaviour. Only meaningful in exclusive mode,
    /// where the app re-emits the original key; otherwise identical to "unset".
    case passthrough
    case shortcut(name: String)
    case key(KeyCombo)
    case launchApp(path: String, name: String)
    case openURL(String)
    case media(MediaKey)
    case layer(LayerOp)
    case macro(id: UUID)

    public var display: String {
        switch self {
        case .none: return "無効"
        case .transparent: return "▽"
        case .passthrough: return "デフォルト動作"
        case .shortcut(let n): return "⌘⇧ " + n
        case .key(let k): return k.display
        case .launchApp(_, let name): return "起動: \(name)"
        case .openURL(let u): return "URL: \(u)"
        case .media(let m): return m.displayName
        case .layer(let op): return op.display
        case .macro: return "マクロ"
        }
    }
    public var isTransparent: Bool { if case .transparent = self { return true }; return false }
    public var layerOp: LayerOp? { if case .layer(let op) = self { return op }; return nil }
}
