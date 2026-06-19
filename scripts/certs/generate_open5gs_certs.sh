#!/bin/bash
# Generate PKI certificates for Open5GS network functions with PQC support
# This script generates certificates for each NF with configurable algorithms

set -euo pipefail

CERT_DIR="${CERT_DIR:-$(dirname "$0")/../../certs}"
OPENSSL="${OPENSSL:-openssl}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
SIGN_ALG="${SIGN_ALG:-secp256r1}"
KEM_ALG="${KEM_ALG:-secp256r1}"

export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "=== Generating Open5GS NF certificates ==="
echo "Sign Algorithm: $SIGN_ALG"
echo "KEM Algorithm: $KEM_ALG"

# Generate Root CA
echo "=== Generating Root CA ==="
mkdir -p ca
cd ca

$OPENSSL genpkey -algorithm EC \
    -pkeyopt ec_paramgen_curve:secp256r1 \
    -out ca_key.pem 2>/dev/null

$OPENSSL req -new -x509 \
    -key ca_key.pem \
    -out ca_cert.pem \
    -days 3650 \
    -subj "/C=NL/ST=Noord-Holland/L=Amsterdam/O=PQC-5G-CA/CN=PQC-5G Root CA" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

echo "Root CA generated"
cd "$CERT_DIR"

# Network functions in Open5GS
NFS=("nrf" "amf" "upf" "udr" "udm" "ausf" "nssf" "bsf" "pcf" "smf")

for nf in "${NFS[@]}"; do
    echo "=== Generating certificate for NF: $nf ==="
    
    nf_dir="$CERT_DIR/$nf"
    mkdir -p "$nf_dir"
    cd "$nf_dir"
    
    # Generate NF private key
    case "$SIGN_ALG" in
        secp256r1|secp384r1|secp521r1)
            curve="${SIGN_ALG}"
            $OPENSSL genpkey -algorithm EC \
                -pkeyopt ec_paramgen_curve:"$curve" \
                -out tls.key 2>/dev/null
            ;;
        rsa*)
            bits="${SIGN_ALG#rsa}"
            bits="${bits:-2048}"
            $OPENSSL genpkey -algorithm RSA \
                -pkeyopt rsa_keygen_bits:"$bits" \
                -out tls.key 2>/dev/null
            ;;
        *)
            # Try OQS provider
            $OPENSSL genpkey -algorithm "$SIGN_ALG" \
                -out tls.key 2>/dev/null || {
                echo "Warning: Using ECC fallback for $SIGN_ALG"
                $OPENSSL genpkey -algorithm EC \
                    -pkeyopt ec_paramgen_curve:secp256r1 \
                    -out tls.key 2>/dev/null
            }
            ;;
    esac
    
    # Create CSR with SAN
    cat > csr.cnf << EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C = NL
ST = Noord-Holland
L = Amsterdam
O = Open5GS
OU = $nf
CN = open5gs

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = open5gs
DNS.2 = localhost
DNS.3 = $nf.open5gs
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
    
    $OPENSSL req -new \
        -key tls.key \
        -out csr.pem \
        -config csr.cnf 2>/dev/null
    
    # Sign with CA
    $OPENSSL x509 -req \
        -in csr.pem \
        -CA "$CERT_DIR/ca/ca_cert.pem" \
        -CAkey "$CERT_DIR/ca/ca_key.pem" \
        -CAcreateserial \
        -out tls.crt \
        -days 365 \
        -extensions v3_req \
        -extfile <(cat << EXTEOF
subjectAltName=DNS:open5gs,DNS:localhost,DNS:$nf.open5gs,IP:127.0.0.1,IP:::1
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
EXTEOF
        ) 2>/dev/null
    
    # Create full chain
    cat tls.crt "$CERT_DIR/ca/ca_cert.pem" > chain.pem
    
    echo "Certificate generated: $nf_dir/tls.crt"
    cd "$CERT_DIR"
done

echo ""
echo "=== Certificate generation complete ==="
echo "Certificates stored in: $CERT_DIR"
echo "Each NF directory contains: tls.key, tls.crt, chain.pem"
echo ""
echo "To copy certs to Open5GS config directory:"
echo "  for nf in ${NFS[*]}; do"
echo "    cp $CERT_DIR/\$nf/tls.{key,crt} /etc/open5gs/tls/\$nf/"
echo "  done"
