# mic-probe — Fire TV リモコン内蔵マイクの取得検証（2026-11-06）

結論: **macOS で Fire TV リモコンのマイク音声を受信・Opus 復号・再生できた**（ユーザーが自分の声と確認）。

## 手順
```bash
swiftc -O -o micprobe micprobe.swift
clang -O2 $(pkg-config --cflags --libs opus) -o opus2wav opus2wav.c
# 排他モードのアプリが動いていると開けないので先に終了させる
./micprobe captures          # マイクボタンを押している間だけ録音。Ctrl+C で終了
./opus2wav captures/segment-1.opuspkts captures/segment-1.wav && afplay captures/segment-1.wav
```

## 実測
- ディスクリプタ（`IOHIDDeviceGetProperty(kIOHIDReportDescriptorKey)`、149 バイト）: vendor page 0xFF00 に
  `F0` Input 80B（音声）、`F1` Input 3B、`F2` Output 1B（開始/停止）、`F3` Output 10B、`EF` Input 3B（アプリキー）。Linux の解析と同一。
- マイク押下: consumer report `02 21 02 00 00`（usage 0x0221）、解放 `02 00 00 00 00`。
- 開始/停止: `IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0xF2, buf, len)` は
  **buf=[01] だと 0xe00002bc (kIOReturnError)**、**buf=[F2 01]（Report ID を先頭に含める）だと成功**。停止 `[F2 00]` も同様。
- 音声: `0xF0` 80 バイト固定、TOC 0xB8（CELT-only WB 20ms mono、1 フレーム/パケット）、約 44 pkt/s（理論 50。BLE 接続間隔によるドロップの可能性）。
  停止コマンド後に 3 パケット遅れて到着する。
- 復号: libopus 16kHz mono、1 パケット = 320 サンプル。194/194 成功。発話区間の RMS −13 dBFS、ピーク −3.5 dBFS。

## 次の仮想マイク実装に必要な作業
1. 排他モード helper への統合: 現在 helper が seize しているので、音声の受信と `0xF2` 送信は helper 側で行い XPC でアプリへ流す（または helper 内で完結）。
2. 常駐する Opus デコーダ（libopus を同梱 or AudioToolbox の `kAudioFormatOpus` で `AudioConverter` 復号）とジッタバッファ（44→50 pkt/s の欠損は PLC で補間: `opus_decode(..., NULL, 0, ...)`）。
3. 仮想入力デバイス: Core Audio の AudioServerPlugIn（HAL プラグイン、`/Library/Audio/Plug-Ins/HAL`、管理者権限でインストール）か、macOS 14+ の CoreAudio `AudioDriverKit` 拡張。PCM 16kHz→48kHz のリサンプリングも必要。
4. Push-to-Talk 以外（常時）は不要。マイク押下中だけストリームを流し、無音時はゼロを供給。
