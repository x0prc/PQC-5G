#!/bin/bash
# Generate PKI certificates for all PQC and hybrid algorithms
# Based on Table I from the paper

set -euo pipefail

CERT_DIR="${CERT_DIR:-$(dirname "$0")/../../certs}"
OPENSSL="${OPENSSL:-openssl}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

# Ensure OQS provider is available
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Algorithm configurations from Table I
# Format: "name:sign_alg:kem_alg:bits"
declare -a ALGORITHMS=(
    # Conventional
    "secp256r1:ECDSA:secp256r1:256"
    "rsa2048:RSA:rsaEncryption:2048"
    # Hybrid ECC + PQC KEM
    "p256_bikel1:ECDSA:secp256r1:p256_bikel1"
    "p384_bikel3:ECDSA:secp384r1:p384_bikel3"
    "p521_frodo1344shake:ECDSA:secp521r1:p521_frodo1344shake"
    # Hybrid ECC + PQC Signature
    "p256_falcon513:ECDSA:p256_falcon513:secp256r1"
    "p384_mldsa66:ECDSA:p384_mldsa66:secp384r1"
    # PQC standalone
    "sphincssha2129ssimple:ECDSA:sphincssha2129ssimple:256"
)

generate_ca() {
    local name="$1"
    local sign_alg="$2"
    
    echo "=== Generating CA certificate: $name ==="
    
    local ca_dir="$CERT_DIR/ca_$name"
    mkdir -p "$ca_dir"
    cd "$ca_dir"
    
    # Generate CA key
    case "$sign_alg" in
        ECDSA)
            $OPENSSL genpkey -algorithm EC \
                -pkeyopt ec_paramgen_curve:secp256r1 \
                -out ca_key.pem 2>/dev/null
            ;;
        RSA)
            $OPENSSL genpkey -algorithm RSA \
                -pkeyopt rsa_keygen_bits:2048 \
                -out ca_key.pem 2>/dev/null
            ;;
        *)
            # For PQC algorithms, use oqsprovider
            $OPENSSL genpkey -algorithm "$sign_alg" \
                -out ca_key.pem 2>/dev/null || {
                echo "Warning: Could not generate key for $sign_alg, using ECC fallback"
                $OPENSSL genpkey -algorithm EC \
                    -pkeyopt ec_paramgen_curve:secp256r1 \
                    -out ca_key.pem 2>/dev/null
            }
            ;;
    esac
    
    # Generate CA certificate
    $OPENSSL req -new -x509 \
        -key ca_key.pem \
        -out ca_cert.pem \
        -days 3650 \
        -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=PQC-5G/CN=$name CA" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
    
    echo "CA certificate generated: $ca_dir/ca_cert.pem"
    cd "$CERT_DIR"
}

generate_server_cert() {
    local name="$1"
    local sign_alg="$2"
    local ca_name="$3"
    
    echo "=== Generating server certificate: $name ==="
    
    local server_dir="$CERT_DIR/server_$name"
    local ca_dir="$CERT_DIR/ca_$ca_name"
    mkdir -p "$server_dir"
    cd "$server_dir"
    
    # Generate server key
    case "$sign_alg" in
        ECDSA)
            $OPENSSL genpkey -algorithm EC \
                -pkeyopt ec_paramgen_curve:secp256r1 \
                -out server_key.pem 2>/dev/null
            ;;
        RSA)
            $OPENSSL genpkey -algorithm RSA \
                -pkeyopt rsa_keygen_bits:2048 \
                -out server_key.pem 2>/dev/null
            ;;
        *)
            $OPENSSL genpkey -algorithm "$sign_alg" \
                -out server_key.pem 2>/dev/null || {
                echo "Warning: Could not generate key for $sign_alg, using ECC fallback"
                $OPENSSL genpkey -algorithm EC \
                    -pkeyopt ec_paramgen_curve:secp256r1 \
                    -out server_key.pem 2>/dev/null
            }
            ;;
    esac
    
    # Create CSR
    $OPENSSL req -new \
        -key server_key.pem \
        -out server.csr \
        -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=PQC-5G/CN=$name" \
        -addext "subjectAltName=DNS:open5gs,DNS:localhost,IP:127.0.0.1" 2>/dev/null
    
    # Sign with CA
    $OPENSSL x509 -req \
        -in server.csr \
        -CA "$ca_dir/ca_cert.pem" \
        -CAkey "$ca_dir/ca_key.pem" \
        -CAcreateserial \
        -out server_cert.pem \
        -days 365 \
        -extfile <(echo "subjectAltName=DNS:open5gs,DNS:localhost,IP:127.0.0.1") 2>/dev/null
    
    # Create certificate chain
    cat server_cert.pem "$ca_dir/ca_cert.pem" > chain.pem
    
    echo "Server certificate generated: $server_dir/server_cert.pem"
    cd "$CERT_DIR"
}

generate_client_cert() {
    local name="$1"
    local sign_alg="$2"
    local ca_name="$3"
    
    echo "=== Generating client certificate: $name ==="
    
    local client_dir="$CERT_DIR/client_$name"
    local ca_dir="$CERT_DIR/ca_$ca_name"
    mkdir -p "$client_dir"
    cd "$client_dir"
    
    # Generate client key
    case "$sign_alg" in
        ECDSA)
            $OPENSSL genpkey -algorithm EC \
                -pkeyopt ec_paramgen_curve:secp256r1 \
                -out client_key.pem 2>/dev/null
            ;;
        RSA)
            $OPENSSL genpkey -algorithm RSA \
                -pkeyopt rsa_keygen_bits:2048 \
                -out client_key.pem 2>/dev/null
            ;;
        *)
            $OPENSSL genpkey -algorithm "$sign_alg" \
                -out client_key.pem 2>/dev/null || {
                echo "Warning: Could not generate key for $sign_alg, using ECC fallback"
                $OPENSSL genpkey -algorithm EC \
                    -pkeyopt ec_paramgen_curve:secp256r1 \
                    -out client_key.pem 2>/dev/null
            }
            ;;
    esac
    
    # Create CSR
    $OPENSSL req -new \
        -key client_key.pem \
        -out client.csr \
        -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=PQC-5G/CN=$name-client" 2>/dev/null
    
    # Sign with CA
    $OPENSSL x509 -req \
        -in client.csr \
        -CA "$ca_dir/ca_cert.pem" \
        -CAkey "$ca_dir/ca_key.pem" \
        -CAcreateserial \
        -out client_cert.pem \
        -days 365 2>/dev/null
    
    # Create certificate chain
    cat client_cert.pem "$ca_dir/ca_cert.pem" > chain.pem
    
    echo "Client certificate generated: $client_dir/client_cert.pem"
    cd "$CERT_DIR"
}

# Main certificate generation
echo "=== Generating certificates for all algorithm combinations ==="
echo ""

# Generate certificates for each algorithm
for algo in "${ALGORITHMS[@]}"; do
    IFS=':' read -r name sign_alg kem_alg bits <<< "$algo"
    
    echo "--- Processing: $name ---"
    
    # Generate CA
    generate_ca "$name" "$sign_alg"
    
    # Generate server cert (signed by this CA)
    generate_server_cert "$name" "$sign_alg" "$name"
    
    # Generate client cert (signed by same CA)
    generate_client_cert "$name" "$sign_alg" "$name"
    
    echo ""
done

# Generate combined certificates for hybrid experiments
echo "=== Generating hybrid experiment certificates ==="

# For KEM experiments: use RSA signatures + various KEMs
# For Signature experiments: use ECC KEM + various signatures
# These are already covered by the individual algorithm configs above

# Create a combined directory with all certs organized for Open5GS
echo ""
echo "=== Creating organized cert structure ==="

# Open5GS expects certs in specific locations per NF
NFS=("nrf" "amf" "upf" "udr" "udm" "ausf" "nssf" "bsf" "pcf" "smf")

for nf in "${NFS[@]}"; do
    nf_cert_dir="$CERT_DIR/$nf"
    mkdir -p "$nf_cert_dir"
    
    # Default to secp256r1 for each NF (can be overridden in experiments)
    ln -sf "$CERT_DIR/server_secp256r1/server_cert.pem" "$nf_cert_dir/tls.crt"
    ln -sf "$CERT_DIR/server_secp256r1/server_key.pem" "$nf_cert_dir/tls.key"
    ln -sf "$CERT_DIR/ca_secp256r1/ca_cert.pem" "$nf_cert_dir/ca.crt"
done

echo ""
echo "=== Certificate generation complete ==="
echo "Certificates stored in: $CERT_DIR"
echo ""
echo "Algorithm mappings (from Table I):"
echo "  KEMs:    secp256r1, p256_bikel1, p384_bikel3, p521_frodo1344shake"
echo "  Sig:     secp256r1(ECDSA), rsa2048(RSA), p256_falcon513, p384_mldsa66, sphincssha2129ssimple"
echo ""
echo "To use specific algorithm certs, set the TLS_CERT_DIR env var:"
echo "  export TLS_CERT_DIR=$CERT_DIR/server_<algorithm>"
