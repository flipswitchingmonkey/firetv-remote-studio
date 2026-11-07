import Foundation

/// Resolves which action a button triggers given the layer state, and tracks
/// press/release so layer keys behave like QMK's MO/TG/TO/DF.
public final class LayerEngine {
    public private(set) var layers: [Layer]
    public private(set) var defaultLayer: Int
    public private(set) var toggled: Set<Int> = []
    private var momentary: [Int: Int] = [:]          // layer -> number of MO keys holding it
    private var held: [RemoteButton: Action] = [:]    // action captured at press time

    public enum Effect: Equatable {
        case execute(Action)
        /// A non-layer action's button was released (needed for passthrough key-up / repeat stop).
        case release(Action)
        case layerStateChanged
        case defaultLayerChanged(Int)
    }

    public init(layers: [Layer], defaultLayer: Int) {
        self.layers = layers
        self.defaultLayer = layers.indices.contains(defaultLayer) ? defaultLayer : 0
    }

    /// Replace layer data (e.g. after editing). Held keys keep their captured action.
    public func update(layers: [Layer], defaultLayer: Int) {
        self.layers = layers
        self.defaultLayer = layers.indices.contains(defaultLayer) ? defaultLayer : 0
        toggled = toggled.filter { layers.indices.contains($0) }
        momentary = momentary.filter { layers.indices.contains($0.key) }
    }

    public var activeLayers: [Int] {
        var s = Set<Int>([defaultLayer]).union(toggled).union(momentary.filter { $0.value > 0 }.keys)
        s = s.filter { layers.indices.contains($0) }
        return s.sorted(by: >)
    }
    public var highestActiveLayer: Int { activeLayers.first ?? 0 }
    public var isMomentaryActive: Bool { momentary.values.contains { $0 > 0 } }

    /// Walks active layers from highest to lowest, skipping transparent bindings.
    /// Returns nil when no layer sets the button (distinct from an explicit `.none`).
    public func resolveBinding(_ b: RemoteButton) -> Action? {
        for li in activeLayers {
            let a = layers[li].action(for: b)
            if !a.isTransparent { return a }
        }
        return nil
    }
    /// Unset buttons keep their original behaviour (`.passthrough`).
    public func resolve(_ b: RemoteButton) -> Action { resolveBinding(b) ?? .passthrough }

    public func press(_ b: RemoteButton) -> [Effect] {
        if held[b] != nil { return [] }   // already down: duplicate press event
        let action = resolve(b)
        held[b] = action
        switch action {
        case .layer(let op):
            guard layers.indices.contains(op.layer) else { return [] }
            switch op {
            case .momentary(let n):
                momentary[n, default: 0] += 1
                return [.layerStateChanged]
            case .toggle(let n):
                // Exclusive toggle: TG(n) makes n the only toggled layer; pressing it again (or
                // toggling the default layer) returns to the base layer. MO layers still stack.
                if n == defaultLayer || toggled == [n] { toggled = [] } else { toggled = [n] }
                return [.layerStateChanged]
            case .switchTo(let n):
                toggled = n == defaultLayer ? [] : [n]
                return [.layerStateChanged]
            case .setDefault(let n):
                defaultLayer = n
                toggled.remove(n)
                return [.defaultLayerChanged(n), .layerStateChanged]
            }
        case .none, .transparent:
            return []
        default:
            return [.execute(action)]
        }
    }

    public func release(_ b: RemoteButton) -> [Effect] {
        guard let action = held.removeValue(forKey: b) else { return [] }
        switch action {
        case .layer(.momentary(let n)):
            if let c = momentary[n] { momentary[n] = max(0, c - 1); if momentary[n] == 0 { momentary[n] = nil } }
            return [.layerStateChanged]
        case .layer, .none, .transparent:
            return []
        default:
            return [.release(action)]
        }
    }

    /// Device disconnected / monitoring stopped: nothing can be held any more.
    public func releaseAll() -> [Effect] {
        var out: [Effect] = []
        for (_, a) in held { if case .layer = a {} else if case .none = a {} else if case .transparent = a {} else { out.append(.release(a)) } }
        let had = !held.isEmpty || !momentary.isEmpty
        held = [:]; momentary = [:]
        if had { out.append(.layerStateChanged) }
        return out
    }
}
