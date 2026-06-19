#!/bin/bash
# Build Open5GS with OQS-enabled dependencies

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
NPROC="${NPROC:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"
BUILD_DIR="${BUILD_DIR:-/tmp/pqc-build}"
OPEN5GS_DIR="${OPEN5GS_DIR:-$BUILD_DIR/open5gs}"

# Install build dependencies (Ubuntu/Debian)
install_deps() {
    echo "=== Installing build dependencies ==="
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        cmake \
        ninja-build \
        flex \
        bison \
        libgcrypt20-dev \
        libidn11-dev \
        libmongoc-dev \
        libbson-dev \
        libnghttp2-dev \
        libyaml-dev \
        libtalloc-dev \
        libffi-dev \
        libpcre2-dev \
        libsctp-dev \
        libmicrohttpd-dev \
        libcurl4-openssl-dev \
        libnghttp2-dev
}

# Clone and patch Open5GS
clone_open5gs() {
    echo "=== Cloning Open5GS ==="
    if [ ! -d "$OPEN5GS_DIR" ]; then
        git clone --depth 1 https://github.com/open5gs/open5gs.git "$OPEN5GS_DIR"
    fi
}

# Apply PQC patches to Open5GS
apply_patches() {
    echo "=== Applying PQC patches ==="
    cd "$OPEN5GS_DIR"
    
    PATCH_DIR="$(dirname "$0")/../../patches"
    if [ -d "$PATCH_DIR" ] && ls "$PATCH_DIR"/*.patch 1>/dev/null 2>&1; then
        for patch_file in "$PATCH_DIR"/*.patch; do
            echo "Applying $(basename "$patch_file")"
            git apply "$patch_file" || true
        done
    fi
    
    echo "Note: Manual patches may be required for:"
    echo "  - libcurl interface to set KEM/signature algorithms"
    echo "  - libnghttp2 interface for HTTP/2 with PQC TLS"
    echo "  - Certificate loading per NF based on configured algorithms"
}

# Build Open5GS
build_open5gs() {
    echo "=== Building Open5GS ==="
    cd "$OPEN5GS_DIR"
    
    # Ensure it uses our custom OpenSSL
    export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$INSTALL_PREFIX/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:$INSTALL_PREFIX/lib64:${LD_LIBRARY_PATH:-}"
    
    mkdir -p build
    cd build
    
    cmake -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="-I$INSTALL_PREFIX/include -L$INSTALL_PREFIX/lib" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$INSTALL_PREFIX/lib" \
        ..
    
    ninja -j"$NPROC"
    sudo ninja install
    sudo ldconfig
}

install_deps
clone_open5gs
apply_patches
build_open5gs

echo "=== Open5GS built with PQC support ==="
echo "Binaries installed to /usr/bin/"
