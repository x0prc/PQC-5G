#!/bin/bash
# Build libnghttp2 against OQS-enabled OpenSSL

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
NPROC="${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"
BUILD_DIR="${BUILD_DIR:-/tmp/pqc-build}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Building libnghttp2 with OQS OpenSSL ==="
if [ ! -d "nghttp2" ]; then
    git clone --depth 1 https://github.com/nghttp2/nghttp2.git
fi
cd nghttp2
git submodule update --init
autoreconf -fi
./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-lib-only \
    --with-openssl="$INSTALL_PREFIX" \
    CFLAGS="-I$INSTALL_PREFIX/include" \
    LDFLAGS="-L$INSTALL_PREFIX/lib -Wl,-rpath,$INSTALL_PREFIX/lib"
make -j"$NPROC"
sudo make install
sudo ldconfig

echo "=== libnghttp2 installed to $INSTALL_PREFIX ==="
