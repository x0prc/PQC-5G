#!/bin/bash
# Main setup script for PQC-5G project
# This script sets up the complete environment for testing PQC in 5G Core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== PQC-5G Setup Script ==="
echo "Based on: Post-Quantum Cryptography in the 5G Core (arXiv:2512.20243)"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root"
    exit 1
fi

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

# Install system dependencies
install_system_deps() {
    echo ""
    echo "=== Installing System Dependencies ==="
    
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y \
                build-essential \
                cmake \
                ninja-build \
                git \
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
                python3-pip \
                python3-venv
            ;;
        centos|rhel|fedora)
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y \
                cmake \
                ninja-build \
                git \
                flex \
                bison \
                libgcrypt-devel \
                libidn-devel \
                libmongoc-devel \
                libbson-devel \
                nghttp2-devel \
                libyaml-devel \
                libtalloc-devel \
                libffi-devel \
                pcre2-devel \
                lksctp-tools-devel \
                libmicrohttpd-devel \
                python3-pip
            ;;
        macos)
            brew install \
                cmake \
                ninja \
                flex \
                bison
            ;;
        *)
            echo "Warning: Unsupported OS. Please install dependencies manually."
            ;;
    esac
}

# Build components
build_openssl() {
    echo ""
    echo "=== Building OpenSSL with liboqs ==="
    bash "$SCRIPT_DIR/build/build_openssl_oqs.sh"
}

build_nghttp2() {
    echo ""
    echo "=== Building libnghttp2 ==="
    bash "$SCRIPT_DIR/build/build_libnghttp2.sh"
}

build_curl() {
    echo ""
    echo "=== Building libcurl ==="
    bash "$SCRIPT_DIR/build/build_libcurl.sh"
}

build_open5gs() {
    echo ""
    echo "=== Building Open5GS ==="
    bash "$SCRIPT_DIR/build/build_open5gs.sh"
}

# Generate certificates
generate_certs() {
    echo ""
    echo "=== Generating PQC Certificates ==="
    bash "$SCRIPT_DIR/certs/generate_open5gs_certs.sh"
}

# Configure Open5GS
configure_open5gs() {
    echo ""
    echo "=== Configuring Open5GS for PQC ==="
    bash "$SCRIPT_DIR/open5gs/configure_pqc.sh"
}

# Main setup flow
main() {
    echo ""
    echo "This script will:"
    echo "1. Install system dependencies"
    echo "2. Build OpenSSL with liboqs (PQC support)"
    echo "3. Build libnghttp2 with PQC OpenSSL"
    echo "4. Build libcurl with PQC OpenSSL"
    echo "5. Build Open5GS with PQC support"
    echo "6. Generate PQC certificates"
    echo "7. Configure Open5GS for PQC experiments"
    echo ""
    
    read -p "Continue with setup? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Run setup steps
    install_system_deps
    build_openssl
    build_nghttp2
    build_curl
    build_open5gs
    generate_certs
    configure_open5gs
    
    echo ""
    echo "=== Setup Complete ==="
    echo ""
    echo "Next steps:"
    echo "1. Install UERANSIM (see README.md for instructions)"
    echo "2. Configure network settings"
    echo "3. Run experiments:"
    echo "   ./scripts/experiment/run_experiments.sh"
    echo ""
    echo "4. Analyze results:"
    echo "   python3 scripts/experiment/analyze_results.py"
    echo ""
}

# Run main function
main
