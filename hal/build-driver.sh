#!/bin/zsh
# Builds FireTVRemoteMicrophone.driver (Core Audio HAL plug-in) into hal/build/
set -e
cd "$(dirname "$0")"
OUT=build/FireTVRemoteMicrophone.driver
rm -rf build && mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
clang -O2 -Wall -bundle -fvisibility=hidden -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 \
  -framework CoreAudio -framework CoreFoundation \
  -Wl,-exported_symbol,_FireTVMic_Create \
  -o "$OUT/Contents/MacOS/FireTVRemoteMicrophone" FireTVMic.c
cp Info.plist "$OUT/Contents/Info.plist"
[ -f ../icon/AppIcon.icns ] && cp ../icon/AppIcon.icns "$OUT/Contents/Resources/DeviceIcon.icns"
IDENTITY="${CODESIGN_IDENTITY:-}"
[ -z "$IDENTITY" ] && IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
[ -z "$IDENTITY" ] && IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')
if [ -n "$IDENTITY" ]; then codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$OUT"; echo "signed: $IDENTITY"; else codesign --force --sign - "$OUT"; fi
echo "built $OUT"
