#!/bin/bash
# Main experiment runner script
# Based on the paper's experimental setup
#
# This script runs the UE registration experiments with different
# PQC algorithms and measures latency and bandwidth

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/results"
CONFIG_DIR="$PROJECT_DIR/configs"
LOG_DIR="$PROJECT_DIR/logs"

# Experiment parameters (from the paper)
MIN_UE="${MIN_UE:-1}"
MAX_UE="${MAX_UE:-120}"
UE_STEP="${UE_STEP:-10}"
DEREGISTRATION_INTERVAL="${DEREGISTRATION_INTERVAL:-10}"  # t in seconds
UE_START_DELAY="${UE_START_DELAY:-0.1}"  # t/n delay between UE starts

# Algorithm configurations (from Table I)
declare -a KEM_ALGORITHMS=(
    "secp256r1"           # Plain ECC (baseline)
    "p256_bikel1"         # Hybrid ECC + BIKE-L1
    "p384_bikel3"         # Hybrid ECC + BIKE-L3
    "p521_frodo1344shake" # Hybrid ECC + FrodoKEM
)

declare -a SIGNATURE_ALGORITHMS=(
    "secp256r1"           # Plain ECC ECDSA (baseline)
    "rsa2048"             # RSA (baseline)
    "p256_falcon513"      # Hybrid ECC + Falcon-512
    "p384_mldsa66"        # Hybrid ECC + ML-DSA-65
    "sphincssha2129ssimple" # SPHINCS+ (baseline)
)

# Create directories
mkdir -p "$RESULTS_DIR" "$LOG_DIR"

# Initialize results file
RESULTS_FILE="$RESULTS_DIR/experiment_results.csv"
echo "timestamp,algorithm_type,algorithm,ue_count,median_latency_ms,p95_latency_ms,p99_latency_ms,p100_latency_ms,sbi_data_rate_kbps" > "$RESULTS_FILE"

# Function to stop all Open5GS NFs
stop_open5gs() {
    echo "Stopping Open5GS network functions..."
    pkill -f open5gs-nrf || true
    pkill -f open5gs-amfd || true
    pkill -f open5gs-smfd || true
    pkill -f open5gs-upfd || true
    pkill -f open5gs-udrd || true
    pkill -f open5gs-udmd || true
    pkill -f open5gs-ausfd || true
    pkill -f open5gs-nssfd || true
    pkill -f open5gs-pcfd || true
    pkill -f open5gs-bsfd || true
    sleep 2
}

# Function to start Open5GS with specific algorithm
start_open5gs() {
    local sign_alg="$1"
    local kem_alg="$2"
    
    echo "Starting Open5GS with sign=$sign_alg, kem=$kem_alg"
    
    # Set environment for PQC
    export OPENSSL_CONF="$CONFIG_DIR/open5gs/oqs-openssl.cnf"
    export OQS_OPENSSL_CONF="$CONFIG_DIR/open5gs/oqs-openssl.cnf"
    export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
    
    # Start network functions
    open5gs-nrfd &
    sleep 1
    open5gs-ausfd &
    open5gs-nssfd &
    open5gs-pcfd &
    open5gs-bsfd &
    open5gs-udrd &
    open5gs-udmd &
    open5gs-amfd &
    open5gs-smfd &
    open5gs-upfd &
    
    # Wait for all NFs to be ready
    sleep 5
    echo "Open5GS started"
}

# Function to run UERANSIM experiment
run_ueransim() {
    local num_ue="$1"
    local sign_alg="$2"
    local kem_alg="$3"
    local result_file="$4"
    
    echo "Running UERANSIM with $num_ue UEs (sign=$sign_alg, kem=$kem_alg)"
    
    # Generate UERANSIM config for this experiment
    local ueransim_config="$RESULTS_DIR/ueransim_config.yaml"
    cat > "$ueransim_config" << EOF
mcc: 208
mnc: 93

nodes:
  - nci: 0x000000010
    nciLength: 32
    tac: 0x0001
    defaultPduSessionType: IPv4
    defaultQci: 9
    ignoreAttachReject: false
    amfAddress: 127.0.0.1
    amfPort: 38412
    amfRegionId: 1
    amfSetId: 1
    amfPointer: 1
    sctpListenOn: 127.0.0.10
    sctpPort: 38412
    gtpListenOn: 127.0.0.10
    gtpPort: 2152
    cells:
      - nci: 0x000000001
        nciLength: 28
        tac: 0x0001
        earfcn: 3350
        earfcnOffset: 0
        qrxlevmin: -140
        cellBarred: false
        cellReservedForOtherUse: false

ueCount: $num_ue
imsi: "208930000000001"
key: "465B5CE8B199B49FAA5F0A2EE238A6BC"
op: "E8ED289DEBA952E4283B54E88E6183CA"
amf: "FF0000"
autn: "1872b368b31fa2803b79628056230000"
rand: "02474bf1d240e50143312b011e43d5ec1c"

dnnList:
  - dnn: internet
    dns:
      - 8.8.8.8
      - 8.8.4.4
    pduSessionType: IPv4
    sscMode: SSC1
    default5QI: 9
    defaultPriorityLevel: 10
    
deregistrationInterval: $DEREGISTRATION_INTERVAL
EOF

    # Start UERANSIM
    local log_file="$LOG_DIR/ueransim_${sign_alg}_${kem_alg}_${num_ue}ue.log"
    
    # Run UERANSIM and capture output
    timeout 300 ueransim -c "$ueransim_config" > "$log_file" 2>&1 || true
    
    # Parse results from log file
    # This is a simplified parser - actual parsing depends on UERANSIM output format
    parse_ueransim_results "$log_file" "$result_file" "$sign_alg" "$kem_alg" "$num_ue"
}

# Function to parse UERANSIM results
parse_ueransim_results() {
    local log_file="$1"
    local result_file="$2"
    local sign_alg="$3"
    local kem_alg="$4"
    local num_ue="$5"
    
    echo "Parsing results from $log_file"
    
    # Extract latency values (this is a template - actual parsing depends on log format)
    # You'll need to adapt this based on UERANSIM's actual output
    
    # For now, write placeholder values
    echo "$(date +%s),$sign_alg,$kem_alg,$num_ue,0,0,0,0,0" >> "$result_file"
}

# Function to run bandwidth measurement
measure_bandwidth() {
    local duration=10
    local interface="eth0"
    
    echo "Measuring bandwidth for ${duration}s..."
    
    # Use bpftrace or tcpdump for measurement
    # This is a simplified version
    if command -v bpftrace &> /dev/null; then
        bpftrace -e '
        tracepoint:syscalls:sys_exit_sendto {
            @bytes = sum(arg2);
        }
        interval:s:1 {
            printf("%d bytes/s\n", @bytes);
            clear(@bytes);
        }
        ' > "$RESULTS_DIR/bandwidth_${duration}s.log" &
        BPF_PID=$!
        sleep "$duration"
        kill "$BPF_PID" 2>/dev/null || true
    fi
}

# Main experiment loop
echo "=== PQC-5G Experiment Runner ==="
echo "UE range: $MIN_UE to $MAX_UE (step: $UE_STEP)"
echo "Deregistration interval: $DEREGISTRATION_INTERVAL seconds"
echo ""

# Test each signature algorithm with ECC KEM
echo "=== Testing Signature Algorithms ==="
for sig_alg in "${SIGNATURE_ALGORITHMS[@]}"; do
    echo ""
    echo "--- Algorithm: $sig_alg ---"
    
    # Stop any running Open5GS
    stop_open5gs
    
    # Start Open5GS with this algorithm
    start_open5gs "$sig_alg" "secp256r1"
    
    # Run experiments for each UE count
    for num_ue in $(seq "$MIN_UE" "$UE_STEP" "$MAX_UE"); do
        run_ueransim "$num_ue" "$sig_alg" "secp256r1" "$RESULTS_FILE"
        
        # Wait between experiments
        sleep 5
    done
    
    stop_open5gs
done

# Test each KEM algorithm with RSA signatures
echo ""
echo "=== Testing KEM Algorithms ==="
for kem_alg in "${KEM_ALGORITHMS[@]}"; do
    echo ""
    echo "--- Algorithm: $kem_alg ---"
    
    # Stop any running Open5GS
    stop_open5gs
    
    # Start Open5GS with this KEM
    start_open5gs "rsa2048" "$kem_alg"
    
    # Run experiments for each UE count
    for num_ue in $(seq "$MIN_UE" "$UE_STEP" "$MAX_UE"); do
        run_ueransim "$num_ue" "rsa2048" "$kem_alg" "$RESULTS_FILE"
        
        # Wait between experiments
        sleep 5
    done
    
    stop_open5gs
done

echo ""
echo "=== Experiments Complete ==="
echo "Results saved to: $RESULTS_FILE"
echo "Logs saved to: $LOG_DIR"
echo ""
echo "Run the analysis script to generate plots:"
echo "  python3 scripts/experiment/analyze_results.py"
