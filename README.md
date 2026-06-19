# PQC-5G

Implementation based on the paper: [Post-Quantum Cryptography in the 5G Core](https://arxiv.org/abs/2512.20243)

## Overview

This project implements the experimental setup from the paper to evaluate the impact of post-quantum cryptography (PQC) on 5G core network performance. The implementation includes:

- **Open5GS** - 5G core network with PQC-enabled TLS
- **UERANSIM** - UE/RAN simulator for generating test traffic
- **OpenSSL + liboqs** - PQC cryptographic support via oqs-provider
- **Certificate generation** - PKI infrastructure for all PQC algorithms

## Algorithms Tested

Based on Table I from the paper:

| Type | Algorithm | Description |
|------|-----------|-------------|
| **KEM** | secp256r1 | Plain ECC (baseline) |
| | p256_bikel1 | Hybrid ECC + BIKE-L1 |
| | p384_bikel3 | Hybrid ECC + BIKE-L3 |
| | p521_frodo1344shake | Hybrid ECC + FrodoKEM-1344 |
| **Signature** | secp256r1 | ECDSA (baseline) |
| | rsa2048 | RSA-2048 (baseline) |
| | p256_falcon513 | Hybrid ECC + Falcon-512 |
| | p384_mldsa66 | Hybrid ECC + ML-DSA-65 |
| | sphincssha2129ssimple | SPHINCS+ SHA2-128s |

## Prerequisites

### Hardware Requirements
- CPU: 4+ cores (Intel i7 or equivalent)
- RAM: 16GB+ recommended
- Network: Two machines connected via 1 Gbit/s LAN (for Open5GS + UERANSIM separation)

### Software Requirements
- Linux (Ubuntu 20.04+) or macOS
- C/C++ toolchain (gcc/g++, cmake, make)
- Git

## Quick Start

### 1. Clone the repository

```bash
`git clone https://github.com/x0prc/PQC-5G`
`cd PQC-5G`
```

### 2. Run the setup script

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

This will:
- Install system dependencies
- Build OpenSSL with liboqs (PQC support)
- Build libnghttp2 and libcurl with PQC OpenSSL
- Build Open5GS with PQC support
- Generate PQC certificates
- Configure Open5GS for PQC experiments

### 3. Install UERANSIM

```bash
# Clone UERANSIM
cd /tmp
git clone https://github.com/aligungr/UERANSIM.git
cd UERANSIM

# Build UERANSIM
make
sudo cp build/ueransim /usr/local/bin/
```

### 4. Run Experiments

```bash
# Run all experiments with default parameters
./scripts/experiment/run_experiments.sh

# Or customize parameters:
export MIN_UE=1
export MAX_UE=120
export UE_STEP=10
export DEREGISTRATION_INTERVAL=10
./scripts/experiment/run_experiments.sh
```

### 5. Analyze Results

```bash
# Generate plots and analysis
python3 scripts/experiment/analyze_results.py

# Results will be in results/plots/
```

## Experiment Parameters

The experiments measure:

1. **Latency**: Time from registration request to registration accept
2. **Bandwidth**: Total data in bytes sent via SBI interfaces
3. **Scaling**: Impact of varying number of UEs (1-120)

### Default Configuration

- **UE Re-registration interval**: 10 seconds
- **UE count range**: 1 to 120
- **UE step size**: 10
- **Start delay**: t/n seconds between UE starts

## References

- Attema, T., et al. (2025). "Post-Quantum Cryptography in the 5G Core." arXiv:2512.20243
- Open5GS: https://github.com/open5gs/open5gs
- UERANSIM: https://github.com/aligungr/UERANSIM
- liboqs: https://github.com/open-quantum-safe/liboqs
- oqs-provider: https://github.com/open-quantum-safe/openssl/tree/oqs-provider
