#!/bin/bash
# Quick test script to verify the setup works correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== PQC-5G Setup Verification ==="
echo ""

# Check if Open5GS is available
check_open5gs() {
    echo "Checking Open5GS..."
    if command -v open5gs-nrfd &> /dev/null; then
        echo "  ✓ Open5GS found: $(which open5gs-nrfd)"
        return 0
    else
        echo "  ✗ Open5GS not found in PATH"
        return 1
    fi
}

# Check if UERANSIM is available
check_ueransim() {
    echo "Checking UERANSIM..."
    if command -v ueransim &> /dev/null; then
        echo "  ✓ UERANSIM found: $(which ueransim)"
        return 0
    else
        echo "  ✗ UERANSIM not found in PATH"
        return 1
    fi
}

# Check if OpenSSL has OQS provider
check_openssl() {
    echo "Checking OpenSSL with OQS provider..."
    
    # Check if custom OpenSSL is installed
    if [ -f /usr/local/bin/openssl ]; then
        echo "  ✓ Custom OpenSSL found at /usr/local/bin/openssl"
        
        # Try to load OQS provider
        export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
        if /usr/local/bin/openssl version 2>&1 | grep -q "OQS"; then
            echo "  ✓ OQS provider loaded"
            return 0
        else
            echo "  ⚠ OQS provider not detected (may still work)"
            return 0
        fi
    else
        echo "  ✗ Custom OpenSSL not found"
        return 1
    fi
}

# Check certificates
check_certs() {
    echo "Checking certificates..."
    
    cert_dir="$PROJECT_DIR/certs"
    if [ -d "$cert_dir" ]; then
        cert_count=$(find "$cert_dir" -name "*.pem" -o -name "*.crt" -o -name "*.key" 2>/dev/null | wc -l)
        if [ "$cert_count" -gt 0 ]; then
            echo "  ✓ Found $cert_count certificate files in $cert_dir"
            return 0
        else
            echo "  ✗ No certificate files found in $cert_dir"
            return 1
        fi
    else
        echo "  ✗ Certificate directory not found"
        return 1
    fi
}

# Check project structure
check_structure() {
    echo "Checking project structure..."
    
    required_dirs=(
        "scripts/build"
        "scripts/certs"
        "scripts/experiment"
        "scripts/open5gs"
        "configs/open5gs"
        "configs/ueransim"
    )
    
    all_good=true
    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_DIR/$dir" ]; then
            echo "  ✓ $dir"
        else
            echo "  ✗ $dir (missing)"
            all_good=false
        fi
    done
    
    if $all_good; then
        return 0
    else
        return 1
    fi
}

# Run all checks
echo "Running verification checks..."
echo ""

errors=0

check_open5gs || ((errors++))
echo ""

check_ueransim || ((errors++))
echo ""

check_openssl || ((errors++))
echo ""

check_certs || ((errors++))
echo ""

check_structure || ((errors++))
echo ""

# Summary
echo "=== Verification Summary ==="
if [ $errors -eq 0 ]; then
    echo "All checks passed! ✓"
    echo ""
    echo "You can now run experiments:"
    echo "  ./scripts/experiment/run_experiments.sh"
else
    echo "$errors check(s) failed"
    echo ""
    echo "Please fix the issues above before running experiments."
    echo "Run the setup script if you haven't already:"
    echo "  ./scripts/setup.sh"
fi
