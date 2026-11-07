#!/bin/zsh
# Builds a universal (arm64 + x86_64) libopus.0.dylib with a macOS 14 deployment target into
# vendor/libopus/. build-app.sh bundles this copy when present; otherwise it falls back to the
# Homebrew library (which is linked for the host OS version only, fine for local use).
set -e
cd "$(dirname "$0")/.."
VER="${OPUS_VERSION:-1.5.2}"
URL="https://downloads.xiph.org/releases/opus/opus-$VER.tar.gz"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "downloading $URL"
curl -fsSL "$URL" -o "$WORK/opus.tar.gz"
tar -xzf "$WORK/opus.tar.gz" -C "$WORK"
SRC="$WORK/opus-$VER"
for ARCH in arm64 x86_64; do
  echo "building $ARCH"
  ( cd "$SRC" && make distclean >/dev/null 2>&1 || true
    CFLAGS="-O2 -arch $ARCH -mmacosx-version-min=14.0" LDFLAGS="-arch $ARCH -mmacosx-version-min=14.0" \
    ./configure --host="$ARCH-apple-darwin" --disable-static --enable-shared --disable-extra-programs --disable-doc --prefix="$WORK/out-$ARCH" >/dev/null
    make -j"$(sysctl -n hw.ncpu)" >/dev/null && make install >/dev/null )
done
mkdir -p vendor/libopus
lipo -create "$WORK/out-arm64/lib/libopus.0.dylib" "$WORK/out-x86_64/lib/libopus.0.dylib" -output vendor/libopus/libopus.0.dylib
install_name_tool -id @rpath/libopus.0.dylib vendor/libopus/libopus.0.dylib
cp "$SRC/COPYING" vendor/libopus/COPYING
echo "opus $VER" > vendor/libopus/VERSION
lipo -info vendor/libopus/libopus.0.dylib
otool -l vendor/libopus/libopus.0.dylib | grep -A1 'minos' | head -2
echo "built vendor/libopus/libopus.0.dylib"
