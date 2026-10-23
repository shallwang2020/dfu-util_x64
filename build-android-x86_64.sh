#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
API="${ANDROID_API:-23}"
HOST_TAG=""

if [[ -z "$NDK" || ! -d "$NDK" ]]; then
  echo "Set ANDROID_NDK_HOME to an installed Android NDK (r25 or newer)." >&2
  exit 2
fi
for tool in git make autoconf automake libtoolize pkg-config; do
  command -v "$tool" >/dev/null || { echo "Missing host build tool: $tool" >&2; exit 2; }
done
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) HOST_TAG=linux-x86_64 ;;
  Darwin-x86_64) HOST_TAG=darwin-x86_64 ;;
  Darwin-arm64) HOST_TAG=darwin-arm64 ;;
  *) echo "Unsupported NDK host: $(uname -s)-$(uname -m)" >&2; exit 2 ;;
esac
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
[[ -x "$TOOLCHAIN/bin/x86_64-linux-android${API}-clang" ]] || {
  echo "Could not find the Android x86_64 NDK compiler under $TOOLCHAIN" >&2; exit 2;
}
WORK="${BUILD_DIR:-$ROOT/.android-build}"
mkdir -p "$WORK" "$ROOT/dist"

# On failure, show the end of autoconf's config.log, where the real reason for
# a configure error is recorded (the console only says "See config.log").
on_error() {
  local log
  for log in "$WORK"/*-src/config.log; do
    [[ -f "$log" ]] || continue
    echo "::group::tail of $log" >&2
    tail -n 80 "$log" >&2 || true
    echo "::endgroup::" >&2
  done
}
trap on_error ERR

fetch() {
  local url="$1" path="$2"
  if [[ ! -d "$path/.git" ]]; then git clone --depth 1 "$url" "$path"; else git -C "$path" pull --ff-only; fi
}
fetch https://github.com/Stefan-Schmidt/dfu-util.git "$WORK/dfu-util-src"
fetch https://github.com/libusb/libusb.git "$WORK/libusb-src"

export PATH="$TOOLCHAIN/bin:$PATH"
export CC="$TOOLCHAIN/bin/x86_64-linux-android${API}-clang"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export CFLAGS="-O2 -fPIE"
export LDFLAGS="-pie"
export PKG_CONFIG_LIBDIR="$WORK/prefix/lib/pkgconfig"
export PKG_CONFIG_PATH=""
export PKG_CONFIG_ALLOW_CROSS=1

# Configure libusb as a static Android library.
(
  cd "$WORK/libusb-src"
  # NOCONFIGURE=1 stops autogen.sh from running a native configure: without
  # --host, configure tries to execute Android binaries on the build host and
  # fails with "cannot run C compiled programs". The cross configure runs below.
  NOCONFIGURE=1 ./autogen.sh
  ./configure --host=x86_64-linux-android --prefix="$WORK/prefix" \
    --disable-udev --disable-shared --enable-static
  make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  make install
)

# Build dfu-util against the cross-compiled static libusb.
(
  cd "$WORK/dfu-util-src"
  ./autogen.sh
  ./configure --host=x86_64-linux-android --prefix="$WORK/prefix" \
    PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR"
  make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  cp src/dfu-util "$ROOT/dist/dfu-util"
)
"$STRIP" "$ROOT/dist/dfu-util"
echo "Built: $ROOT/dist/dfu-util"
file "$ROOT/dist/dfu-util" 2>/dev/null || true
