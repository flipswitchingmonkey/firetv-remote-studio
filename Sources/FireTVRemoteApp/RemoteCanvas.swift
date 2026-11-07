import SwiftUI
import FireTVCore

/// Vector-drawn Fire TV (Alexa Voice) remote. Design space: 100 x 380 units.
struct RemoteCanvas: View {
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState

    enum Shape { case circle, pill, dpad(Edge) }
    struct Spot { let b: RemoteButton; let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat; let shape: Shape; let symbol: String? }

    static let bodyW: CGFloat = 100, bodyH: CGFloat = 380
    static let dpadC = CGPoint(x: 50, y: 92), dpadR: CGFloat = 32
    static let spots: [Spot] = [
        Spot(b: .power, x: 20, y: 24, w: 14, h: 14, shape: .circle, symbol: "power"),
        Spot(b: .mic, x: 50, y: 24, w: 16, h: 16, shape: .circle, symbol: "mic.fill"),
        // D-pad wedges share the ring's centre; the wedge shape picks its quadrant.
        Spot(b: .up, x: 50, y: 92, w: 0, h: 0, shape: .dpad(.top), symbol: "chevron.up"),
        Spot(b: .down, x: 50, y: 92, w: 0, h: 0, shape: .dpad(.bottom), symbol: "chevron.down"),
        Spot(b: .left, x: 50, y: 92, w: 0, h: 0, shape: .dpad(.leading), symbol: "chevron.left"),
        Spot(b: .right, x: 50, y: 92, w: 0, h: 0, shape: .dpad(.trailing), symbol: "chevron.right"),
        Spot(b: .select, x: 50, y: 92, w: 28, h: 28, shape: .circle, symbol: nil),
        Spot(b: .back, x: 22, y: 150, w: 18, h: 18, shape: .circle, symbol: "arrow.uturn.backward"),
        Spot(b: .home, x: 50, y: 150, w: 18, h: 18, shape: .circle, symbol: "house.fill"),
        Spot(b: .menu, x: 78, y: 150, w: 18, h: 18, shape: .circle, symbol: "line.3.horizontal"),
        Spot(b: .rewind, x: 22, y: 182, w: 18, h: 18, shape: .circle, symbol: "backward.fill"),
        Spot(b: .playPause, x: 50, y: 182, w: 18, h: 18, shape: .circle, symbol: "playpause.fill"),
        Spot(b: .fastForward, x: 78, y: 182, w: 18, h: 18, shape: .circle, symbol: "forward.fill"),
        Spot(b: .volumeUp, x: 22, y: 216, w: 18, h: 18, shape: .circle, symbol: "plus"),
        Spot(b: .mute, x: 50, y: 216, w: 18, h: 18, shape: .circle, symbol: "speaker.slash.fill"),
        Spot(b: .tv, x: 78, y: 216, w: 18, h: 18, shape: .circle, symbol: "tv"),
        Spot(b: .volumeDown, x: 22, y: 246, w: 18, h: 18, shape: .circle, symbol: "minus"),
        Spot(b: .a1, x: 30, y: 300, w: 34, h: 16, shape: .pill, symbol: nil),
        Spot(b: .a2, x: 70, y: 300, w: 34, h: 16, shape: .pill, symbol: nil),
        Spot(b: .a3, x: 30, y: 326, w: 34, h: 16, shape: .pill, symbol: nil),
        Spot(b: .a4, x: 70, y: 326, w: 34, h: 16, shape: .pill, symbol: nil),
    ]

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 28
            let s = min((geo.size.width - 2 * pad) / Self.bodyW, (geo.size.height - 2 * pad) / Self.bodyH)
            ZStack {
                RemoteBody(scale: s)
                ForEach(Self.spots, id: \.b) { spot in
                    RemoteKey(spot: spot, s: s)
                        .position(x: spot.x * s, y: spot.y * s)
                }
                Text("fire tv").font(.system(size: 5.5 * s, weight: .semibold)).foregroundStyle(Theme.text3)
                    .position(x: 50 * s, y: 362 * s)
                    .accessibilityHidden(true)
            }
            .frame(width: Self.bodyW * s, height: Self.bodyH * s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(Theme.s3)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.anim) { editor.selectedButton = nil } }   // click empty space to deselect
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fire TV remote control")
    }
}

/// Body shell and D-pad ring.
struct RemoteBody: View {
    let scale: CGFloat
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let w = RemoteCanvas.bodyW * scale, h = RemoteCanvas.bodyH * scale
        let r = 18 * scale
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(scheme == .dark ? Color(white: 0.16) : Color(white: 0.30))
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .stroke(Color.primary.opacity(scheme == .dark ? 0.18 : 0.10), lineWidth: 1.5)
            // D-pad ring
            Circle().fill(Color.black.opacity(0.22))
                .frame(width: RemoteCanvas.dpadR * 2 * scale, height: RemoteCanvas.dpadR * 2 * scale)
                .position(x: RemoteCanvas.dpadC.x * scale, y: RemoteCanvas.dpadC.y * scale)
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: RemoteCanvas.dpadR * 2 * scale, height: RemoteCanvas.dpadR * 2 * scale)
                .position(x: RemoteCanvas.dpadC.x * scale, y: RemoteCanvas.dpadC.y * scale)
        }
        .frame(width: w, height: h)
    }
}

/// D-pad wedge shape (quarter of the ring).
struct DPadWedge: SwiftUI.Shape {
    let edge: Edge
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOut = rect.width / 2, rIn = rect.width * 0.24
        let start: Angle
        switch edge { case .top: start = .degrees(-135); case .trailing: start = .degrees(-45); case .bottom: start = .degrees(45); case .leading: start = .degrees(135) }
        var p = Path()
        p.addArc(center: c, radius: rOut, startAngle: start + .degrees(4), endAngle: start + .degrees(86), clockwise: false)
        p.addArc(center: c, radius: rIn, startAngle: start + .degrees(86), endAngle: start + .degrees(4), clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct RemoteKey: View {
    let spot: RemoteCanvas.Spot
    let s: CGFloat
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState
    @Environment(\.colorScheme) var scheme
    @State private var hover = false

    var info: ButtonInfo { ctl.info(for: spot.b) }
    var binding: Action? { ctl.config.layers[safe: editor.editingLayer]?.bindings[spot.b] }
    var selected: Bool { editor.selectedButton == spot.b }
    var pressed: Bool { ctl.pressedNow.contains(spot.b) }
    var assignable: Bool { info.restriction == AssignRestriction.none }

    var body: some View {
        Button { withAnimation(Theme.anim) { editor.selectedButton = spot.b } } label: {
            ZStack {
                face
                content
            }
            .frame(width: frameSize.width, height: frameSize.height)
            .contentShape(AnyShape(hitShape))
            .scaleEffect(pressed ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Theme.anim, value: pressed)
        .animation(Theme.anim, value: hover)
        .help(helpText)
        .accessibilityLabel(spot.b.displayName)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var frameSize: CGSize {
        if case .dpad = spot.shape { let d = RemoteCanvas.dpadR * 2 * s; return CGSize(width: d, height: d) }
        return CGSize(width: spot.w * s, height: spot.h * s)
    }

    var hitShape: any SwiftUI.Shape {
        switch spot.shape {
        case .circle: return Circle()
        case .pill: return Capsule()
        case .dpad(let e): return DPadWedge(edge: e)
        }
    }

    var fillColor: Color {
        if pressed { return Theme.accent.opacity(0.55) }
        if selected { return Theme.accent.opacity(0.30) }
        if hover { return Color.white.opacity(scheme == .dark ? 0.16 : 0.26) }
        if case .dpad = spot.shape { return Color.white.opacity(0.04) }
        return Color.white.opacity(assignable ? (scheme == .dark ? 0.10 : 0.18) : 0.05)
    }
    var strokeColor: Color {
        if selected || pressed { return Theme.accent }
        if info.restriction == .codeUnknown { return Color.white.opacity(0.25) }
        return Color.white.opacity(assignable ? 0.22 : 0.10)
    }

    @ViewBuilder var face: some View {
        switch spot.shape {
        case .circle:
            Circle().fill(fillColor)
            Circle().stroke(strokeColor, style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: info.restriction == .codeUnknown ? [3, 2] : []))
        case .pill:
            Capsule().fill(fillColor)
            Capsule().stroke(strokeColor, lineWidth: selected ? 2 : 1)
        case .dpad(let e):
            DPadWedge(edge: e).fill(fillColor)
            if selected || pressed { DPadWedge(edge: e).stroke(Theme.accent, lineWidth: 2) }
        }
    }

    @ViewBuilder var content: some View {
        let fg: Color = assignable ? Color.white.opacity(0.92) : Color.white.opacity(0.45)
        let size = max(7, 6.5 * s)
        if case .dpad(let e) = spot.shape {
            Image(systemName: spot.symbol ?? "").font(.system(size: size, weight: .semibold)).foregroundStyle(fg)
                .offset(dpadOffset(e))
        } else if spot.b == .select {
            Text("OK").font(.system(size: 6.5 * s, weight: .bold)).foregroundStyle(fg)
        } else if let sym = spot.symbol {
            Image(systemName: sym).font(.system(size: size, weight: .medium)).foregroundStyle(fg)
        } else {
            Text(spot.b.shortName).font(.system(size: 6.5 * s, weight: .bold)).foregroundStyle(fg)
        }
        // Corner badge: assignment state (custom / disabled), or why the button is locked.
        if !assignable {
            if case .dpad = spot.shape {} else {
                Image(systemName: info.restriction == .osHandled ? "lock.fill" : "questionmark")
                    .font(.system(size: 3.5 * s, weight: .bold)).foregroundStyle(Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(1.5 * s)
            }
        } else if let badge = assignmentBadge {
            badge.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(1.2 * s)
                .offset(dpadBadgeOffset)
        }
    }
    var dpadBadgeOffset: CGSize {
        guard case .dpad(let e) = spot.shape else { return .zero }
        let d = RemoteCanvas.dpadR * s
        switch e { case .top: return CGSize(width: -d * 0.55, height: d * 0.08); case .bottom: return CGSize(width: -d * 0.55, height: d * 1.55); case .leading: return CGSize(width: -d * 1.55, height: d * 0.6); case .trailing: return CGSize(width: 0, height: d * 0.6) }
    }
    /// Orange dot = custom action, grey slash = disabled, grey ring = inherits (upper layers). Default/unset shows nothing.
    @ViewBuilder var assignmentBadge: (some View)? {
        let size = 3.2 * s
        switch binding {
        case .some(.none): Image(systemName: "slash.circle.fill").font(.system(size: size)).foregroundStyle(Color.white.opacity(0.55))
        case .some(.transparent): Circle().stroke(Color.white.opacity(0.45), lineWidth: 1).frame(width: size, height: size)
        case .some(.passthrough): EmptyView()
        case .some: Circle().fill(Theme.accent).frame(width: size, height: size)
        case nil: if editor.editingLayer != 0 { Circle().stroke(Color.white.opacity(0.35), lineWidth: 1).frame(width: size, height: size) }
        }
    }
    func dpadOffset(_ e: Edge) -> CGSize {
        let d = RemoteCanvas.dpadR * 0.64 * s
        switch e { case .top: return CGSize(width: 0, height: -d); case .bottom: return CGSize(width: 0, height: d); case .leading: return CGSize(width: -d, height: 0); case .trailing: return CGSize(width: d, height: 0) }
    }
    var helpText: String {
        var t = spot.b.displayName
        if let c = info.code { t += "  [\(c)]" }
        switch info.restriction {
        case .osHandled: t += String(localized: "\nActs as macOS standard key (not assignable)")
        case .codeUnknown: t += String(localized: "\nUnlearned (learn on device screen)")
        case .none:
            let fallback = editor.editingLayer == 0 ? String(localized: "Default Behavior (unset)") : String(localized: "Inherit lower layer")
            t += "\n" + (binding.map { $0.display } ?? fallback)
        }
        return t
    }
    var accessibilityValue: String {
        switch info.restriction {
        case .osHandled: return String(localized: "Not assignable")
        case .codeUnknown: return String(localized: "Not learned")
        case .none: return binding?.display ?? String(localized: "Unset")
        }
    }
}
