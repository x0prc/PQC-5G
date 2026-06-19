#!/bin/bash
# Build OpenSSL with liboqs provider for post-quantum cryptography support
# Based on: https://github.com/open-quantum-safe/openssl

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
NPROC="${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"
BUILD_DIR="${BUILD_DIR:-/tmp/pqc-build}"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Building liboqs ==="
if [ ! -d "liboqs" ]; then
    git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git
fi
cd liboqs
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DOQS_MINIMAL_BUILD="KEM_kyber;KEM_bike;KEM_frodo;SIG_dilithium;SIG_falcon;SIG_sphincs" \
      ..
make -j"$NPROC"
sudo make install
sudo ldconfig

cd "$BUILD_DIR"

echo "=== Building OpenSSL with OQS provider ==="
if [ ! -d "openssl" ]; then
    git clone --depth 1 -b oqs-provider-main https://github.com/open-quantum-safe/openssl.git
fi
cd openssl
git clone --depth 1 https://github.com/open-quantum-safe/oqs-provider.git

./Configure \
    --prefix="$INSTALL_PREFIX" \
    --openssldir="$INSTALL_PREFIX/ssl" \
    enable-tls1_3 \
    enable-ntls \
    -DOQS_PROVIDER_DIR="$BUILD_DIR/openssl/oqs-provider" \
    -DCMAKE_ARGS="-DOQS_DIR=$INSTALL_PREFIX" \
    shared

make -j"$NPROC"
sudo make install
sudo ldconfig

echo "=== OpenSSL with OQS provider installed to $INSTALL_PREFIX ==="
openssl version
