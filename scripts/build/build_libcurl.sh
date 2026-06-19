#!/bin/bash
# Build libcurl against OQS-enabled OpenSSL

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
NPROC="${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"
BUILD_DIR="${BUILD_DIR:-/tmp/pqc-build}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Building libcurl with OQS OpenSSL ==="
if [ ! -d "curl" ]; then
    git clone --depth 1 https://github.com/curl/curl.git
fi
cd curl
autoreconf -fi
./configure \
    --prefix="$INSTALL_PREFIX" \
    --with-openssl="$INSTALL_PREFIX" \
    --with-nghttp2 \
    --enable-https \
    --enable-tls13 \
    --disable-ldap \
    --disable-ldaps \
    LDFLAGS="-L$INSTALL_PREFIX/lib -Wl,-rpath,$INSTALL_PREFIX/lib"
make -j"$NPROC"
sudo make install
sudo ldconfig

echo "=== libcurl installed to $INSTALL_PREFIX ==="
curl --version
