import SwiftUI
import AppKit
import ServiceManagement
import FireTVCore

struct SheetFrame<Content: View>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let content: Content
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Theme.title)
                Spacer()
                Button("完了") { dismiss() }.keyboardShortcut(.defaultAction).controlSize(.small)
            }
            .padding(.horizontal, Theme.s4).frame(height: 44)
            Divider()
            content
        }
        .frame(width: width, height: height)
    }
}

// MARK: Layers

struct LayersSheet: View {
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState
    @State private var confirmDelete: Int?
    var body: some View {
        SheetFrame(title: "レイヤー", width: 540, height: 360) {
            VStack(spacing: 0) {
                List {
                    ForEach(ctl.config.layers.indices, id: \.self) { i in
                        HStack(spacing: Theme.s2) {
                            Circle().fill(ctl.activeLayers.contains(i) ? Theme.accent : Theme.border).frame(width: 7, height: 7).help(ctl.activeLayers.contains(i) ? "現在有効" : "")
                            Text("\(i)").font(Theme.mono).foregroundStyle(Theme.text2).frame(width: 16)
                            TextField("名前", text: Binding(get: { ctl.config.layers[safe: i]?.name ?? "" },
                                                           set: { v in ctl.mutate { c in if c.layers.indices.contains(i) { c.layers[i].name = v } } }))
                                .textFieldStyle(.roundedBorder).frame(width: 160)
                            Text("\(ctl.config.layers[i].bindings.count) 件").font(Theme.caption).foregroundStyle(Theme.text2).frame(width: 36)
                            if i == ctl.config.defaultLayer { Label("デフォルト", systemImage: "star.fill").font(Theme.caption).foregroundStyle(Theme.accent).labelStyle(.titleAndIcon) }
                            else { Button("デフォルトに") { ctl.mutate { $0.defaultLayer = i } } }
                            Spacer()
                            Menu {
                                Button("このレイヤーを編集") { editor.editingLayer = i; editor.showLayers = false }
                                Button("複製") { ctl.mutate { _ = $0.duplicateLayer(i) } }
                                Button("割り当てをすべて消去") { ctl.mutate { $0.resetLayer(i) } }
                                Divider()
                                Button("削除", role: .destructive) { confirmDelete = i }.disabled(i == 0)
                            } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 24)
                        }
                        .controlSize(.small)
                        .padding(.vertical, 2)
                    }
                }
                Divider()
                HStack {
                    Button { ctl.mutate { _ = $0.addLayer() } } label: { Label("レイヤーを追加", systemImage: "plus") }
                    Spacer()
                    Text("上の番号ほど優先。未設定のボタンは下位レイヤーを継承します。").font(Theme.caption).foregroundStyle(Theme.text3)
                }
                .controlSize(.small).padding(Theme.s3)
            }
        }
        .alert("レイヤー \(confirmDelete ?? 0) を削除しますか？", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("削除", role: .destructive) { if let i = confirmDelete { ctl.mutate { _ = $0.removeLayer(i) } } }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("このレイヤーを参照する MO/TG/TO/DF は「なし」になります。") }
    }
}

// MARK: Macros

struct MacrosSheet: View {
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState
    var body: some View {
        SheetFrame(title: "マクロ", width: 660, height: 440) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    List(ctl.config.macros, selection: $editor.editingMacro) { m in
                        HStack { Text(m.name).lineLimit(1); Spacer(); Text("\(m.steps.count)").font(Theme.caption).foregroundStyle(Theme.text2) }.tag(m.id)
                    }
                    .listStyle(.inset)
                    Divider()
                    HStack {
                        Button { let m = Macro(name: "マクロ \(ctl.config.macros.count + 1)"); ctl.mutate { $0.macros.append(m) }; editor.editingMacro = m.id } label: { Image(systemName: "plus") }
                        Button { if let id = editor.editingMacro { editor.editingMacro = nil; ctl.mutate { $0.macros.removeAll { $0.id == id } } } } label: { Image(systemName: "minus") }.disabled(editor.editingMacro == nil)
                        Spacer()
                    }.controlSize(.small).padding(6)
                }
                .frame(width: 220)
                Divider()
                if let id = editor.editingMacro, ctl.config.macros.contains(where: { $0.id == id }) {
                    MacroEditor(macroID: id)
                } else {
                    VStack(spacing: 6) {
                        Text("マクロを選択するか + で作成").font(Theme.body).foregroundStyle(Theme.text2)
                        Text("複数のアクションを順に実行し、各ステップの後に遅延を入れられます").font(Theme.caption).foregroundStyle(Theme.text3)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { if editor.editingMacro == nil { editor.editingMacro = ctl.config.macros.first?.id } }
    }
}

struct MacroEditor: View {
    let macroID: UUID
    @EnvironmentObject var ctl: RemoteController
    @State private var editingStep: UUID?
    var macro: Macro { ctl.config.macros.first { $0.id == macroID } ?? Macro(id: macroID, name: "") }
    func edit(_ f: (inout Macro) -> Void) { ctl.mutate { c in if let i = c.macros.firstIndex(where: { $0.id == macroID }) { f(&c.macros[i]) } } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            HStack {
                TextField("名前", text: Binding(get: { macro.name }, set: { v in edit { $0.name = v } })).textFieldStyle(.roundedBorder).frame(width: 220)
                Spacer()
                Button { ctl.executor.execute(.macro(id: macroID)) } label: { Label("テスト実行", systemImage: "play.fill") }.disabled(macro.steps.isEmpty)
            }.controlSize(.small)
            SectionHeader(title: "ステップ")
            List {
                ForEach(Array(macro.steps.enumerated()), id: \.element.id) { i, step in
                    HStack(spacing: Theme.s2) {
                        Text("\(i + 1)").font(Theme.mono).foregroundStyle(Theme.text2).frame(width: 18)
                        Button { editingStep = step.id } label: {
                            HStack { Image(systemName: ActionKind.of(step.action).icon).foregroundStyle(Theme.accent); Text(describe(step.action)).lineLimit(1); Spacer(); Image(systemName: "pencil").foregroundStyle(Theme.text3) }
                                .padding(.horizontal, 8).frame(height: 24).background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: Binding(get: { editingStep == step.id }, set: { if !$0 { editingStep = nil } })) {
                            VStack(alignment: .leading, spacing: Theme.s3) {
                                SectionHeader(title: "ステップ \(i + 1)")
                                StepActionEditor(action: Binding(get: { step.action }, set: { a in edit { if $0.steps.indices.contains(i) { $0.steps[i].action = a } } }))
                            }.padding(Theme.s4).frame(width: 340)
                        }
                        Text("遅延").font(Theme.caption).foregroundStyle(Theme.text2)
                        TextField("ms", value: Binding(get: { step.delayMs }, set: { v in edit { if $0.steps.indices.contains(i) { $0.steps[i].delayMs = max(0, v) } } }), format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 60)
                        Text("ms").font(Theme.caption).foregroundStyle(Theme.text2)
                        Button { edit { if i > 0 { $0.steps.swapAt(i, i - 1) } } } label: { Image(systemName: "arrow.up") }.disabled(i == 0)
                        Button { edit { if $0.steps.indices.contains(i) { $0.steps.remove(at: i) } } } label: { Image(systemName: "trash") }
                    }
                    .controlSize(.small)
                }
                .onMove { from, to in edit { $0.steps.move(fromOffsets: from, toOffset: to) } }
            }
            .listStyle(.inset)
            HStack {
                Menu {
                    ForEach(ActionKind.allCases.filter { $0 != .macro && $0 != .transparent }) { k in
                        Button { if let a = k.defaultAction(firstMacro: nil) { edit { $0.steps.append(MacroStep(action: a)) }; editingStep = macro.steps.last?.id } } label: { Label(k.rawValue, systemImage: k.icon) }
                    }
                } label: { Label("ステップを追加", systemImage: "plus") }.frame(width: 150)
                Spacer()
            }.controlSize(.small)
        }
        .padding(Theme.s4)
    }
    func describe(_ a: Action) -> String { if case .shortcut(let n) = a { return n.isEmpty ? "ショートカット未選択" : n }; return a.display }
}

/// Action editor with its own kind picker (for macro steps).
struct StepActionEditor: View {
    @Binding var action: Action
    @EnvironmentObject var ctl: RemoteController
    var body: some View {
        Picker("種類", selection: Binding(get: { ActionKind.of(action) }, set: { k in if k != ActionKind.of(action), let a = k.defaultAction(firstMacro: nil) { action = a } })) {
            ForEach(ActionKind.allCases.filter { $0 != .macro && $0 != .transparent }) { k in Label(k.rawValue, systemImage: k.icon).tag(k) }
        }.labelsHidden()
        ActionEditor(action: $action)
    }
}

// MARK: Device

struct DeviceSheet: View {
    @EnvironmentObject var ctl: RemoteController
    var body: some View {
        SheetFrame(title: "デバイス", width: 660, height: 470) {
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.s3) {
                        SectionHeader(title: "接続")
                        KVRow(key: "製品", value: "Amazon Remote (Fire TV Stick 4K Select)")
                        KVRow(key: "Vendor / Product", value: "0x0171 / 0x042F", mono: true)
                        KVRow(key: "状態", value: status)
                        KVRow(key: "最後のレポート", value: ctl.lastRawReport, mono: true)
                        KVRow(key: "最後のボタン", value: ctl.lastPressed?.displayName ?? "—")
                        KVRow(key: "未知のコード", value: ctl.lastUnknownCode?.description ?? "—", mono: true)
                        HStack {
                            Button(ctl.isMonitoring ? "監視を停止" : "監視を開始") { ctl.setMonitoring(!ctl.isMonitoring) }
                            Menu("疑似入力") {
                                Button("A1 を押す") { ctl.inject(reportID: 0xEF, bytes: [0xEF, 0xA1, 0, 0]); ctl.inject(reportID: 0xEF, bytes: [0xEF, 0, 0, 0]) }
                                Button("A2 を押す") { ctl.inject(reportID: 0xEF, bytes: [0xEF, 0xA2, 0, 0]); ctl.inject(reportID: 0xEF, bytes: [0xEF, 0, 0, 0]) }
                                Button("TV を押す") { ctl.inject(reportID: 0x02, bytes: [0x02, 0x8D, 0, 0, 0]); ctl.inject(reportID: 0x02, bytes: [0x02, 0, 0, 0, 0]) }
                            }.frame(width: 90)
                        }.controlSize(.small)
                        Divider()
                        SectionHeader(title: "ボタンの対応状況")
                        Text("「学習」を押してから実機でそのボタンを押すと HID コードを記録します。キーボードコードとして届くボタンは macOS が処理するため割り当て不可のままです。").font(Theme.caption).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
                        if let l = ctl.learningButton {
                            HStack { ProgressView().controlSize(.small); Text("「\(l.displayName)」を実機で押してください…").font(Theme.caption); Spacer(); Button("キャンセル") { ctl.learningButton = nil }.controlSize(.small) }
                                .padding(8).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.radius))
                        }
                        ForEach(RemoteButton.allCases) { b in
                            let info = ctl.info(for: b)
                            HStack(spacing: Theme.s2) {
                                Text(b.displayName).font(Theme.caption).lineLimit(1).frame(width: 104, alignment: .leading)
                                Text(info.code?.description ?? "—").font(Theme.mono).foregroundStyle(Theme.text2).frame(width: 40, alignment: .leading)
                                Group {
                                    switch info.restriction {
                                    case .none: Label("割り当て可", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.success)
                                    case .osHandled: Label("macOS 標準キー", systemImage: "lock.fill").foregroundStyle(Theme.warning)
                                    case .codeUnknown: Label("未学習", systemImage: "questionmark.circle").foregroundStyle(Theme.text3)
                                    }
                                }
                                .lineLimit(1).fixedSize()
                                Spacer(minLength: 4)
                                Button("学習") { ctl.learningButton = b }.disabled(ctl.learningButton != nil || !ctl.monitor.isRunning)
                                if ctl.config.learnedCodes[b] != nil { Button("消去") { ctl.mutate { $0.learnedCodes.removeValue(forKey: b) } } }
                            }
                            .font(Theme.caption).controlSize(.mini)
                        }
                    }
                    .padding(Theme.s4)
                }
                .frame(width: 410)
                Divider()
                VStack(alignment: .leading, spacing: Theme.s2) {
                    HStack {
                        SectionHeader(title: "ログ")
                        Toggle("レポートも記録", isOn: Binding(get: { ctl.config.ui.debugLog }, set: { v in ctl.mutate { $0.ui.debugLog = v } })).controlSize(.mini).toggleStyle(.checkbox)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(ctl.log.enumerated()), id: \.offset) { i, l in Text(l).font(Theme.mono).foregroundStyle(Theme.text2).id(i).textSelection(.enabled) }
                            }.padding(6)
                        }
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
                        .onChange(of: ctl.log.count) { _, n in proxy.scrollTo(n - 1) }
                        .onAppear { proxy.scrollTo(ctl.log.count - 1) }
                    }
                }
                .padding(Theme.s3)
            }
        }
    }
    var status: String {
        switch ctl.hidStatus {
        case .connected(let n): return "\(n) — Bluetooth 接続中"
        case .waitingForDevice: return "未接続（待機中）"
        case .blocked(let why): return "⚠ " + why
        case .stopped: return "監視停止中"
        }
    }
}

// MARK: Settings (⌘,)

struct SettingsView: View {
    @EnvironmentObject var ctl: RemoteController
    @EnvironmentObject var editor: EditorState
    @State private var loginItem = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmReset = false
    @State private var axTrusted = ActionExecutor.accessibilityTrusted
    @State private var imTrusted = HIDMonitor.hasInputMonitoringAccess
    var body: some View {
        Form {
            Section("一般") {
                Toggle("リモコンの監視を有効にする", isOn: Binding(get: { ctl.config.ui.monitoringEnabled }, set: { ctl.setMonitoring($0) }))
                Toggle("ログイン時に自動起動", isOn: $loginItem)
                    .onChange(of: loginItem) { _, on in
                        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = nil }
                        catch { loginError = error.localizedDescription; loginItem = SMAppService.mainApp.status == .enabled }
                    }
                if let e = loginError { Text(e).font(Theme.caption).foregroundStyle(Theme.danger) }
                Picker("外観", selection: $editor.appearance) { ForEach(EditorState.Appearance.allCases) { Text($0.label).tag($0) } }
            }
            Section("マイク（Fire TV Remote Microphone）") {
                MicSettings()
            }
            Section("排他モード（すべてのボタンをリマップ）") {
                ExclusiveModeSettings()
            }
            Section("権限") {
                LabeledContent {
                    HStack { Button("許可を要求") { HIDMonitor.requestInputMonitoringAccess() }; Button("システム設定") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!) }; Button("再確認") { imTrusted = HIDMonitor.hasInputMonitoringAccess } }
                } label: { Label(imTrusted ? "入力監視: 許可済み" : "入力監視: 未許可（リモコン読み取りに必要）", systemImage: imTrusted ? "checkmark.circle.fill" : "xmark.circle").foregroundStyle(imTrusted ? Theme.success : Theme.warning) }
                LabeledContent {
                    HStack { Button("許可を要求") { ActionExecutor.promptAccessibility(); axTrusted = ActionExecutor.accessibilityTrusted }; Button("再確認") { axTrusted = ActionExecutor.accessibilityTrusted } }
                } label: { Label(axTrusted ? "アクセシビリティ: 許可済み" : "アクセシビリティ: 未許可（キー送信に必要）", systemImage: axTrusted ? "checkmark.circle.fill" : "xmark.circle").foregroundStyle(axTrusted ? Theme.success : Theme.warning) }
            }
            Section("設定データ") {
                LabeledContent("ファイル") {
                    HStack { Text(ctl.store.url.path).font(Theme.mono).lineLimit(1).truncationMode(.middle); Button("Finder で表示") { NSWorkspace.shared.activateFileViewerSelecting([ctl.store.url]) } }
                }
                if let e = ctl.saveError { Text("保存エラー: \(e)").foregroundStyle(Theme.danger) }
                ForEach(ctl.startupNotices, id: \.self) { Text($0).font(Theme.caption).foregroundStyle(Theme.warning) }
                Button("初期設定に戻す…", role: .destructive) { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .frame(width: 520, height: 420)
        .alert("すべての設定を初期状態に戻しますか？", isPresented: $confirmReset) {
            Button("戻す", role: .destructive) { ctl.resetToDefaults() }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("レイヤー・割り当て・マクロ・学習したコードがすべて消えます。") }
    }
}


/// Helper (LaunchDaemon) install state + the exclusive toggle.
struct ExclusiveModeSettings: View {
    @EnvironmentObject var ctl: RemoteController
    @State private var state = HelperClient.installState
    @State private var error: String?
    var body: some View {
        Group {
            Text("通常モードでは macOS が先に処理するボタン（音量・方向キーなど）は割り当てできません。排他モードでは同梱の helper（root 権限の LaunchDaemon）がリモコンだけを専有し、全ボタンを割り当て可能にします。他のキーボードやマウスには影響しません。").font(Theme.caption).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
            LabeledContent("helper") {
                HStack {
                    Text(stateText).font(Theme.caption).foregroundStyle(state == .enabled ? Theme.success : Theme.warning)
                    if state != .enabled { Button("登録") { register() } }
                    if state == .requiresApproval { Button("システム設定を開く") { HelperClient.openApprovalSettings() } }
                    Button("再確認") { refresh() }
                    if state == .enabled { Button("登録解除") { try? HelperClient.unregister(); refresh() } }
                }
            }
            if let e = error { Text(e).font(Theme.caption).foregroundStyle(Theme.danger) }
            Toggle("排他モードを使う（helper が有効なとき）", isOn: Binding(get: { ctl.exclusiveRequested }, set: { ctl.setExclusive($0) }))
                .disabled(state != .enabled)
            Text(ctl.exclusiveActive ? "● 排他モードで動作中（リモコンは macOS から見えません。アプリ終了・監視停止で解放）" : "○ 通常モードで動作中").font(Theme.caption).foregroundStyle(ctl.exclusiveActive ? Theme.success : Theme.text2)
        }
        .onAppear { refresh() }
    }
    var stateText: String {
        switch state {
        case .enabled: return "有効"
        case .requiresApproval: return "承認待ち: システム設定 → 一般 → ログイン項目と機能拡張 → 「バックグラウンドでの実行を許可」で FireTVRemoteBridge をオン"
        case .notRegistered: return "未登録"
        case .notFound: return "helper が見つかりません（build-app.sh で再ビルド）"
        case .unknown: return "不明"
        }
    }
    func refresh() { state = HelperClient.installState; if state == .enabled, ctl.exclusiveRequested, !ctl.exclusiveActive, ctl.config.ui.monitoringEnabled { ctl.setExclusive(true) } }
    func register() { do { try HelperClient.register(); error = nil } catch { self.error = error.localizedDescription }; refresh() }
}


/// Virtual microphone: enable toggle, driver/device status, install/repair/uninstall.
struct MicSettings: View {
    @EnvironmentObject var ctl: RemoteController
    @State private var installed = RemoteController.micDriverInstalled
    @State private var present = RemoteController.micDevicePresent
    @State private var message: String?
    @State private var busy = false
    @State private var confirmUninstall = false
    var body: some View {
        Group {
            Text("リモコンのマイクボタンを押している間だけ、声が macOS の入力デバイス「Fire TV Remote Microphone」に入ります（Push-to-Talk）。Discord や QuickTime などで一度このデバイスを選べば、以降はボタン操作だけで使えます。").font(Theme.caption).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
            Toggle("マイク機能を有効にする", isOn: Binding(get: { ctl.micEnabled }, set: { ctl.setMicEnabled($0) }))
            LabeledContent("ドライバ") {
                HStack {
                    Label(installed ? (present ? "導入済み・認識中" : "導入済み（デバイス未認識: 再起動で復旧）") : "未導入", systemImage: installed && present ? "checkmark.circle.fill" : "xmark.circle")
                        .font(Theme.caption).foregroundStyle(installed && present ? Theme.success : Theme.warning)
                    Button(installed ? "修復（再インストール）" : "インストール…") { install() }.disabled(busy)
                    Button("再確認") { refresh() }
                    if installed { Button("アンインストール…") { confirmUninstall = true }.disabled(busy) }
                }
            }
            HStack(spacing: 10) {
                Text(stateText).font(Theme.caption).foregroundStyle(ctl.micState == .listening ? Theme.accent : Theme.text2)
                if ctl.micState == .listening || ctl.micStats.packets > 0 {
                    Text("パケット \(ctl.micStats.packets) · 補間 \(ctl.micStats.plcFrames) · エラー \(ctl.micStats.decodeErrors)").font(Theme.caption).foregroundStyle(Theme.text3)
                }
            }
            if let e = ctl.micLastError { Text(e).font(Theme.caption).foregroundStyle(Theme.danger) }
            if let m = message { Text(m).font(Theme.caption).foregroundStyle(Theme.text2) }
            if !ctl.micStats.ringAvailable && ctl.micEnabled { Text("共有バッファ \(ctl.mic.ringPath) を開けません。「修復」で作り直してください。").font(Theme.caption).foregroundStyle(Theme.danger) }
        }
        .onAppear { refresh() }
        .alert("仮想マイクをアンインストールしますか？", isPresented: $confirmUninstall) {
            Button("アンインストール", role: .destructive) { uninstall() }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("HAL ドライバと共有バッファ、helper の登録を削除します。アプリ本体と設定は残ります。") }
    }
    var stateText: String {
        switch ctl.micState { case .disabled: return "○ 無効"; case .ready: return "● 待機中（マイクボタンで入力）"; case .listening: return "● 入力中"; case .draining: return "● 入力中（終了処理）" }
    }
    func refresh() { installed = RemoteController.micDriverInstalled; present = RemoteController.micDevicePresent }
    func runAsAdmin(_ script: String, args: [String], done: @escaping (String?) -> Void) {
        busy = true
        let res = Bundle.main.resourcePath ?? ""
        let cmd = ([res + "/" + script] + args).map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }.joined(separator: " ")
        let src = "do shell script \"/bin/sh \(cmd)\" with administrator privileges"
        DispatchQueue.global().async {
            var err: NSDictionary?
            let out = NSAppleScript(source: src)?.executeAndReturnError(&err)
            DispatchQueue.main.async {
                busy = false
                done(err != nil ? (err?["NSAppleScriptErrorMessage"] as? String ?? "失敗") : out?.stringValue)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { refresh(); ctl.mic.prepare() }
            }
        }
    }
    func install() {
        let drv = (Bundle.main.resourcePath ?? "") + "/FireTVRemoteMicrophone.driver"
        runAsAdmin("install-mic-driver.sh", args: [drv]) { message = $0.map { "インストール: \($0)。デバイスが見えない場合は数秒待って「再確認」" } }
    }
    func uninstall() {
        try? HelperClient.unregister()
        runAsAdmin("uninstall.sh", args: []) { message = $0 }
    }
}
