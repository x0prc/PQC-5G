#!/bin/bash
# Generate experiment configurations for different algorithm combinations
# Based on Table I from the paper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configs/experiments"

mkdir -p "$CONFIG_DIR"

echo "=== Generating Experiment Configurations ==="

# Create config for each signature algorithm (Figure 5 experiments)
create_sig_config() {
    local name="$1"
    local sign_alg="$2"
    
    cat > "$CONFIG_DIR/sig_${name}.env" << EOF
# Signature algorithm experiment: $name
SIGNATURE_ALG=$sign_alg
KEM_ALG=secp256r1
EXPERIMENT_TYPE=sig
DESCRIPTION="Testing signature algorithm: $sign_alg"

# Experiment parameters
MIN_UE=1
MAX_UE=120
UE_STEP=10
DEREGISTRATION_INTERVAL=10
EOF
    echo "Created: $CONFIG_DIR/sig_${name}.env"
}

# Create config for each KEM algorithm (Figure 4 experiments)
create_kem_config() {
    local name="$1"
    local kem_alg="$2"
    
    cat > "$CONFIG_DIR/kem_${name}.env" << EOF
# KEM algorithm experiment: $name
SIGNATURE_ALG=rsa2048
KEM_ALG=$kem_alg
EXPERIMENT_TYPE=kem
DESCRIPTION="Testing KEM algorithm: $kem_alg"

# Experiment parameters
MIN_UE=1
MAX_UE=120
UE_STEP=10
DEREGISTRATION_INTERVAL=10
EOF
    echo "Created: $CONFIG_DIR/kem_${name}.env"
}

# Signature algorithms (from Table I)
create_sig_config "secp256r1" "secp256r1"
create_sig_config "rsa2048" "rsa2048"
create_sig_config "p256_falcon513" "p256_falcon513"
create_sig_config "p384_mldsa66" "p384_mldsa66"
create_sig_config "sphincssha2129ssimple" "sphincssha2129ssimple"

# KEM algorithms (from Table I)
create_kem_config "secp256r1" "secp256r1"
create_kem_config "p256_bikel1" "p256_bikel1"
create_kem_config "p384_bikel3" "p384_bikel3"
create_kem_config "p521_frodo1344shake" "p521_frodo1344shake"

# Create combined experiment config
cat > "$CONFIG_DIR/all_experiments.env" << EOF
# Run all experiments
# This file is sourced by run_experiments.sh

EXPERIMENTS=(
    # Signature experiments (ECC KEM baseline)
    "sig:secp256r1"
    "sig:rsa2048"
    "sig:p256_falcon513"
    "sig:p384_mldsa66"
    "sig:sphincssha2129ssimple"
    
    # KEM experiments (RSA signature baseline)
    "kem:secp256r1"
    "kem:p256_bikel1"
    "kem:p384_bikel3"
    "kem:p521_frodo1344shake"
)

# Common parameters
MIN_UE=1
MAX_UE=120
UE_STEP=10
DEREGISTRATION_INTERVAL=10
EOF
echo "Created: $CONFIG_DIR/all_experiments.env"

# Create a quick test config
cat > "$CONFIG_DIR/quick_test.env" << EOF
# Quick test configuration (small UE count)
SIGNATURE_ALG=secp256r1
KEM_ALG=secp256r1
EXPERIMENT_TYPE=quick_test

MIN_UE=1
MAX_UE=10
UE_STEP=2
DEREGISTRATION_INTERVAL=5
EOF
echo "Created: $CONFIG_DIR/quick_test.env"

echo ""
echo "=== Experiment Configurations Generated ==="
echo ""
echo "To run specific experiments:"
echo "  # Run signature experiment"
echo "  source configs/experiments/sig_p384_mldsa66.env"
echo "  ./scripts/experiment/run_experiments.sh"
echo ""
echo "  # Run KEM experiment"
echo "  source configs/experiments/kem_p384_bikel3.env"
echo "  ./scripts/experiment/run_experiments.sh"
echo ""
echo "  # Run all experiments"
echo "  source configs/experiments/all_experiments.env"
echo "  ./scripts/experiment/run_experiments.sh"
echo ""
echo "  # Quick test"
echo "  source configs/experiments/quick_test.env"
echo "  ./scripts/experiment/run_experiments.sh"
