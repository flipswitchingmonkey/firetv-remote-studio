import SwiftUI
import AppKit
import FireTVCore

/// Right-hand panel: everything about the selected button on the editing layer.
struct InspectorView: View {
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s4) {
                if let b = editor.selectedButton {
                    ButtonHeader(button: b)
                    let info = ctl.info(for: b)
                    switch info.restriction {
                    case .osHandled:
                        Banner(icon: "lock.fill", text: "このボタンは macOS が標準キーとして処理しています。割り当てるには設定(⌘,)で「排他モード」を有効にしてください。リモコンだけを専有し、元の機能は「デフォルト動作」として再現できます。")
                        Button("設定を開く…") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }.controlSize(.small)
                    case .codeUnknown:
                        Banner(icon: "questionmark.circle", text: "HID コードが未確認です。デバイス画面で「学習」すると割り当てできます。")
                        Button("デバイス画面を開く") { editor.showDevice = true }.controlSize(.small)
                    case .none:
                        ActionSection(button: b)
                    }
                    OtherLayersSection(button: b)
                } else {
                    VStack(spacing: Theme.s2) {
                        Image(systemName: "hand.tap").font(.system(size: 28)).foregroundStyle(Theme.text3)
                        Text("リモコンのボタンを選択").font(Theme.body).foregroundStyle(Theme.text2)
                        Text("画面上でクリックするか、実機でボタンを押します").font(Theme.caption).foregroundStyle(Theme.text3)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                }
            }
            .padding(Theme.s4)
        }
    }
}

struct ButtonHeader: View {
    let button: RemoteButton
    @EnvironmentObject var ctl: RemoteController
    var body: some View {
        let info = ctl.info(for: button)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(button.displayName).font(Theme.title)
                Spacer()
                if ctl.pressedNow.contains(button) { StatusPill(text: "押下中", color: Theme.accent) }
            }
            Text(info.code.map { "HID " + $0.description } ?? "HID 未学習").font(Theme.mono).foregroundStyle(Theme.text2)
            if button == .mic && ctl.micEnabled {
                Label("押している間は仮想マイクへ音声を送ります（割り当てとは別に動作）", systemImage: "mic").font(Theme.caption).foregroundStyle(Theme.text2)
            }
        }
    }
}

/// Action kind picker + kind-specific editor + test/clear.
struct ActionSection: View {
    let button: RemoteButton
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState

    var current: Action? { ctl.config.layers[safe: editor.editingLayer]?.bindings[button] }
    var kind: Binding<ActionKind> {
        Binding(get: { current == nil && editor.editingLayer == 0 ? .passthrough : ActionKind.of(current) }, set: { k in
            if k == ActionKind.of(current) { return }
            if k == .transparent && editor.editingLayer == 0 { ctl.clear(button, layer: 0); return }
            if let a = k.defaultAction(firstMacro: ctl.config.macros.first?.id) { ctl.assign(a, to: button, layer: editor.editingLayer) }
        })
    }
    var actionBinding: Binding<Action> {
        Binding(get: { current ?? (editor.editingLayer == 0 && ctl.exclusiveActive ? .passthrough : .transparent) }, set: { ctl.assign($0, to: button, layer: editor.editingLayer) })
    }
    var isSet: Bool { current != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            SectionHeader(title: "アクション · \(ctl.config.layers[safe: editor.editingLayer]?.name ?? "")")
            Picker("種類", selection: kind) {
                ForEach(ActionKind.allCases.filter { !($0 == .transparent && editor.editingLayer == 0) }) { k in
                    Label(k.rawValue, systemImage: k.icon).tag(k)
                }
            }
            .labelsHidden().controlSize(.regular)
            .accessibilityLabel("アクションの種類")

            ActionEditor(action: actionBinding, isSet: isSet)

            HStack(spacing: Theme.s2) {
                if let a = current, canTest(a) {
                    Button { ctl.executor.execute(a) } label: { Label("テスト実行", systemImage: "play.fill") }
                        .keyboardShortcut("t", modifiers: .command)
                }
                Spacer()
                if isSet {
                    Button(role: .destructive) { ctl.clear(button, layer: editor.editingLayer) } label: { Text("割り当て解除") }
                        .help(editor.editingLayer == 0 ? "未設定に戻す" : "未設定（下位レイヤーを継承）に戻す")
                }
            }
            .controlSize(.small)
        }
        .padding(Theme.s3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL))
    }
    func canTest(_ a: Action) -> Bool {
        switch a {
        case .none, .transparent, .layer, .passthrough: return false
        case .shortcut(let n): return !n.isEmpty
        case .launchApp(let p, _): return !p.isEmpty
        default: return true
        }
    }
}

/// Kind-specific editor for an action value. Also used by the macro step editor.
struct ActionEditor: View {
    @Binding var action: Action
    var isSet = true
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState

    var body: some View {
        switch action {
        case .passthrough:
            if let b = editor.selectedButton, let label = ctl.defaultBehavior(of: b) {
                Text((isSet ? "" : "未設定のため") + (ctl.exclusiveActive ? "元の機能をアプリが再現します: \(label)（長押しのリピートも再現）" : "macOS が元の機能を処理します: \(label)")).font(Theme.caption).foregroundStyle(Theme.text2)
            } else {
                Text("このボタンは macOS では元々何も起こしません（デフォルト動作 = 何もしない）。").font(Theme.caption).foregroundStyle(Theme.text2)
            }
        case .none:
            Text("押しても何も起こりません（元の機能も無効）。下位レイヤーの割り当ても使われません。").font(Theme.caption).foregroundStyle(Theme.text2)
        case .transparent:
            Text(editor.editingLayer == 0 ? "未設定です。種類を選ぶと割り当てます。" : "未設定。下位の有効なレイヤーの割り当てを継承します。").font(Theme.caption).foregroundStyle(Theme.text2)
        case .shortcut(let name):
            ShortcutField(name: name) { action = .shortcut(name: $0) }
        case .key(let combo):
            KeyComboEditor(combo: combo) { action = .key($0) }
        case .media(let m):
            Picker("メディア", selection: Binding(get: { m }, set: { action = .media($0) })) {
                ForEach(MediaKey.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.labelsHidden()
            Text("長押しで連続操作（音量なら押している間ずっと変化）").font(Theme.caption).foregroundStyle(Theme.text2)
        case .launchApp(let path, let name):
            AppField(path: path, name: name) { p, n in action = .launchApp(path: p, name: n) }
        case .openURL(let url):
            URLField(url: url) { action = .openURL($0) }
        case .layer(let op):
            LayerOpEditor(op: op) { action = .layer($0) }
        case .macro(let id):
            HStack {
                Picker("マクロ", selection: Binding(get: { id }, set: { action = .macro(id: $0) })) {
                    ForEach(ctl.config.macros) { Text($0.name).tag($0.id) }
                }.labelsHidden()
                Button("編集…") { editor.editingMacro = id; editor.showMacros = true }.controlSize(.small)
            }
            if ctl.config.macros.isEmpty { Text("マクロがありません。「マクロ」から作成してください。").font(Theme.caption).foregroundStyle(Theme.warning) }
        }
    }
}

// MARK: - Shortcut picker

struct ShortcutField: View {
    let name: String
    let onPick: (String) -> Void
    @EnvironmentObject var ctl: RemoteController
    @State private var open = false
    var missing: Bool { !name.isEmpty && ctl.shortcutsLoadError == nil && !ctl.shortcutNames.isEmpty && !ctl.shortcutNames.contains(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { open.toggle() } label: {
                HStack {
                    Image(systemName: "square.2.layers.3d").foregroundStyle(name.isEmpty ? Theme.text3 : Theme.accent)
                    Text(name.isEmpty ? "ショートカットを選択…" : name).foregroundStyle(name.isEmpty ? Theme.text2 : Theme.text).lineLimit(1)
                    Spacer()
                    if ctl.executing.contains("ショートカット \(name)") { ProgressView().controlSize(.mini) }
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(Theme.text2)
                }
                .padding(.horizontal, 8).frame(height: Theme.controlH)
                .background(Theme.panelBG, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(missing ? Theme.danger : Theme.border))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .bottom) {
                ShortcutPicker(current: name) { onPick($0); open = false }
            }
            .accessibilityLabel("ショートカット: \(name.isEmpty ? "未選択" : name)")
            if missing { Label("このショートカットは存在しません", systemImage: "exclamationmark.triangle.fill").font(Theme.caption).foregroundStyle(Theme.danger) }
            if let e = ctl.shortcutsLoadError { Label(e, systemImage: "exclamationmark.triangle.fill").font(Theme.caption).foregroundStyle(Theme.danger) }
        }
    }
}

/// Searchable, keyboard-navigable list of the user's real Shortcuts.
struct ShortcutPicker: View {
    let current: String
    let onPick: (String) -> Void
    @EnvironmentObject var ctl: RemoteController
    @State private var query = ""
    @State private var selection: String?
    @FocusState private var searchFocused: Bool

    var filtered: [String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? ctl.shortcutNames : ctl.shortcutNames.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.text2)
                TextField("ショートカットを検索", text: $query)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .onSubmit { if let s = selection ?? filtered.first { onPick(s) } }
                Button { ctl.refreshShortcuts() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("一覧を再読み込み").disabled(ctl.shortcutsLoading)
                if ctl.shortcutsLoading { ProgressView().controlSize(.mini) }
            }
            .padding(.horizontal, 10).frame(height: 36)
            Divider()
            if let e = ctl.shortcutsLoadError {
                Banner(icon: "exclamationmark.triangle.fill", text: "一覧を取得できません: \(e)", color: Theme.danger).padding(10)
            } else if ctl.shortcutNames.isEmpty && !ctl.shortcutsLoading {
                Text("ショートカットアプリに登録されたショートカットがありません").font(Theme.caption).foregroundStyle(Theme.text2).padding(14)
            } else if filtered.isEmpty {
                Text("「\(query)」に一致なし").font(Theme.caption).foregroundStyle(Theme.text2).padding(14)
            } else {
                List(filtered, id: \.self, selection: $selection) { n in
                    HStack {
                        Text(n).font(Theme.body).lineLimit(1)
                        Spacer()
                        if n == current { Image(systemName: "checkmark").foregroundStyle(Theme.accent).font(.system(size: 11, weight: .semibold)) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(n) }
                    .tag(n)
                }
                .listStyle(.plain)
                .onKeyPress(.return) { if let s = selection { onPick(s); return .handled }; return .ignored }
            }
            Divider()
            Text("\(filtered.count) / \(ctl.shortcutNames.count) 件 · ↑↓ で移動、Return で割り当て").font(Theme.caption).foregroundStyle(Theme.text3)
                .padding(.horizontal, 10).frame(height: 24, alignment: .leading)
        }
        .frame(width: 320, height: 360)
        .onAppear { selection = current.isEmpty ? nil : current; searchFocused = true }
        .onChange(of: query) { _, _ in selection = filtered.first }
    }
}

// MARK: - Other editors

struct KeyComboEditor: View {
    let combo: KeyCombo
    let onChange: (KeyCombo) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("⌘", isOn: Binding(get: { combo.command }, set: { var c = combo; c.command = $0; onChange(c) }))
                Toggle("⇧", isOn: Binding(get: { combo.shift }, set: { var c = combo; c.shift = $0; onChange(c) }))
                Toggle("⌥", isOn: Binding(get: { combo.option }, set: { var c = combo; c.option = $0; onChange(c) }))
                Toggle("⌃", isOn: Binding(get: { combo.control }, set: { var c = combo; c.control = $0; onChange(c) }))
                Spacer()
                Text(combo.display).font(Theme.bodyStrong)
            }
            .toggleStyle(.button).controlSize(.small)
            Picker("キー", selection: Binding(get: { combo.keyCode }, set: { code in
                if let e = KeyTable.all.first(where: { $0.code == code }) { var c = combo; c.keyCode = e.code; c.keyName = e.name; onChange(c) }
            })) {
                Section("文字") { ForEach(KeyTable.letters) { Text($0.name).tag($0.code) } }
                Section("数字") { ForEach(KeyTable.digits) { Text($0.name).tag($0.code) } }
                Section("記号") { ForEach(KeyTable.symbols) { Text($0.name).tag($0.code) } }
                Section("ファンクション") { ForEach(KeyTable.function) { Text($0.name).tag($0.code) } }
                Section("操作") { ForEach(KeyTable.navigation) { Text($0.name).tag($0.code) } }
            }.labelsHidden()
            Text("リモコンのボタンを押している間キーを押し続けます（長押し・Push-to-Talk 対応）").font(Theme.caption).foregroundStyle(Theme.text2)
            if !ActionExecutor.accessibilityTrusted {
                Banner(icon: "hand.raised", text: "キー送信にはアクセシビリティ権限が必要です（設定 → 権限）。")
            }
        }
    }
}

struct AppField: View {
    let path: String
    let name: String
    let onChange: (String, String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if !path.isEmpty {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 20, height: 20)
                    Text(name).font(Theme.body).lineLimit(1)
                } else { Text("アプリ未選択").font(Theme.body).foregroundStyle(Theme.text2) }
                Spacer()
                Menu {
                    ForEach(runningApps, id: \.path) { a in Button(a.name) { onChange(a.path, a.name) } }
                } label: { Text("実行中から") }.frame(width: 90)
                Button("選択…") { pick() }
            }
            .controlSize(.small)
            if !path.isEmpty { Text(path).font(Theme.mono).foregroundStyle(Theme.text3).lineLimit(1).truncationMode(.middle) }
        }
    }
    var runningApps: [(name: String, path: String)] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
            .compactMap { a in a.bundleURL.map { (a.localizedName ?? $0.lastPathComponent, $0.path) } }.sorted { $0.0 < $1.0 }
    }
    func pick() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.applicationBundle]; p.directoryURL = URL(fileURLWithPath: "/Applications"); p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let u = p.url else { return }
        onChange(u.path, u.deletingPathExtension().lastPathComponent)
    }
}

struct URLField: View {
    let url: String
    let onChange: (String) -> Void
    @State private var text = ""
    var valid: Bool { URL(string: text)?.scheme != nil && text.count > 8 }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("https://example.com", text: $text).textFieldStyle(.roundedBorder)
                .onSubmit { if valid { onChange(text) } }
                .onAppear { text = url }
                .onChange(of: url) { _, u in if u != text { text = u } }
            HStack {
                Text(text == url ? "保存済み" : (valid ? "Return で保存" : "有効な URL を入力")).font(Theme.caption).foregroundStyle(text == url ? Theme.text3 : (valid ? Theme.text2 : Theme.warning))
                Spacer()
                if text != url { Button("保存") { onChange(text) }.controlSize(.small).disabled(!valid) }
            }
        }
    }
}

struct LayerOpEditor: View {
    let op: LayerOp
    let onChange: (LayerOp) -> Void
    @EnvironmentObject var ctl: RemoteController
    enum Kind: String, CaseIterable, Identifiable { case mo = "MO", tg = "TG", to = "TO", df = "DF"; var id: String { rawValue } }
    var kind: Kind { switch op { case .momentary: return .mo; case .toggle: return .tg; case .switchTo: return .to; case .setDefault: return .df } }
    func make(_ k: Kind, _ n: Int) -> LayerOp { switch k { case .mo: return .momentary(n); case .tg: return .toggle(n); case .to: return .switchTo(n); case .df: return .setDefault(n) } }
    var desc: String {
        switch kind {
        case .mo: return "押している間だけ有効 (Momentary)"
        case .tg: return "押すたびに有効/無効を切替。他の TG レイヤーは解除され、デフォルトレイヤーへの TG は基本に戻る (Toggle)"
        case .to: return "そのレイヤーだけを有効にする (Switch)"
        case .df: return "デフォルトレイヤーを変更し、再起動後も保持 (Default)"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("操作", selection: Binding(get: { kind }, set: { onChange(make($0, op.layer)) })) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            Picker("レイヤー", selection: Binding(get: { op.layer }, set: { onChange(make(kind, $0)) })) {
                ForEach(ctl.config.layers.indices, id: \.self) { Text("\($0) · \(ctl.config.layers[$0].name)").tag($0) }
            }.labelsHidden()
            Text(desc).font(Theme.caption).foregroundStyle(Theme.text2)
        }
    }
}

/// Compact view of this button on the other layers, with jump-to-edit.
struct OtherLayersSection: View {
    let button: RemoteButton
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState
    var body: some View {
        let others = ctl.config.layers.indices.filter { $0 != editor.editingLayer }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "ほかのレイヤー")
                ForEach(others, id: \.self) { i in
                    let a = ctl.config.layers[i].bindings[button]
                    Button { editor.editingLayer = i } label: {
                        HStack {
                            Text("\(i) · \(ctl.config.layers[i].name)").font(Theme.caption).foregroundStyle(Theme.text2).frame(width: 110, alignment: .leading).lineLimit(1)
                            Text(a.map(describe) ?? (i == 0 ? "未設定" : "継承")).font(Theme.caption).foregroundStyle(a == nil ? Theme.text3 : Theme.text).lineLimit(1)
                            Spacer()
                            if ctl.activeLayers.contains(i) { Circle().fill(Theme.accent).frame(width: 5, height: 5).help("現在有効") }
                        }
                        .padding(.horizontal, 8).frame(height: 24)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("このレイヤーを編集")
                }
            }
        }
    }
    func describe(_ a: Action) -> String {
        if case .macro(let id) = a { return "マクロ: " + (ctl.config.macros.first { $0.id == id }?.name ?? "?") }
        if case .shortcut(let n) = a { return n.isEmpty ? "ショートカット未選択" : n }
        return a.display
    }
}
