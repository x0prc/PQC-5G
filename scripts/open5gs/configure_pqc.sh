# Open5GS PQC Configuration Generator
# This script patches Open5GS config files to enable PQC TLS

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/etc/open5gs}"
CERT_DIR="${CERT_DIR:-/etc/open5gs/tls}"
SIGN_ALG="${SIGN_ALG:-secp256r1}"

echo "=== Configuring Open5GS for PQC ==="
echo "Signature Algorithm: $SIGN_ALG"
echo "Certificate Directory: $CERT_DIR"

# Function to add TLS config to a YAML file
add_tls_config() {
    local yaml_file="$1"
    local nf_name="$2"
    
    if [ ! -f "$yaml_file" ]; then
        echo "Warning: $yaml_file not found, skipping"
        return
    fi
    
    echo "Patching $yaml_file for NF: $nf_name"
    
    # Backup original
    cp "$yaml_file" "${yaml_file}.bak"
    
    # Check if TLS section already exists
    if ! grep -q "^    tls:" "$yaml_file"; then
        # Add TLS configuration after the sbi section
        # This is a simplified approach - manual review may be needed
        echo "Note: TLS configuration needs to be added manually to $yaml_file"
        echo "Required configuration:"
        cat << EOF
  tls:
    enabled: true
    certfile: $CERT_DIR/$nf_name/tls.crt
    keyfile: $CERT_DIR/$nf_name/tls.key
    cacertfile: $CERT_DIR/ca/ca_cert.pem
EOF
    fi
}

# Network functions and their default config paths
declare -A NF_CONFIGS=(
    ["nrf"]="/etc/open5gs/nrf.yaml"
    ["amf"]="/etc/open5gs/amf.yaml"
    ["smf"]="/etc/open5gs/smf.yaml"
    ["upf"]="/etc/open5gs/upf.yaml"
    ["udm"]="/etc/open5gs/udm.yaml"
    ["udr"]="/etc/open5gs/udr.yaml"
    ["ausf"]="/etc/open5gs/ausf.yaml"
    ["nssf"]="/etc/open5gs/nssf.yaml"
    ["pcf"]="/etc/open5gs/pcf.yaml"
    ["bsf"]="/etc/open5gs/bsf.yaml"
)

# Process each NF
for nf in "${!NF_CONFIGS[@]}"; do
    config_file="${NF_CONFIGS[$nf]}"
    if [ -f "$config_file" ]; then
        add_tls_config "$config_file" "$nf"
    fi
done

# Create OQS OpenSSL configuration
echo "=== Creating OQS OpenSSL configuration ==="
OQS_CONF="$CONFIG_DIR/oqs-openssl.cnf"
cat > "$OQS_CONF" << 'EOF'
openssl_conf = openssl_init

[openssl_init]
provider_sect = provider_sect
alg_section = alg_sect

[provider_sect]
default = default_sect
oqs = oqs_sect

[default_sect]
activate = 1

[oqs_sect]
activate = 1
module = /usr/local/lib/liboqs-provider.so

[alg_sect]
# Signature algorithms
sigAlgs = SIG_DILITHIUM2,SIG_DILITHIUM3,SIG_DILITHIUM5,SIG_FALCON512,SIG_FALCON1024,SIG_SPHINCSPLUS-SHA2-128s-simple,SIG_SPHINCSPLUS-SHA2-128f-simple

# Named groups for KEM
groups = X25519Kyber768Draft00,P-256Kyber768Draft00,P-384Kyber1024Draft00,P-521Kyber1024Draft00,SecP256r1Kyber768Draft00,SecP384r1Kyber1024Draft00,SecP521r1Kyber1024Draft00,BIKE:L1,BIKE:L3,FrodoKEM:AES-FrodoKEM-640-AES,FrodoKEM:AES-FrodoKEM-976-AES,FrodoKEM:AES-FrodoKEM-1344-AES

# Signature groups
sigGroups = DILITHIUM2,DILITHIUM3,DILITHIUM5,FALCON512,FALCON1024,SPHINCSPLUS-SHA2-128s-simple,SPHINCSPLUS-SHA2-128f-simple
EOF

echo "OQS configuration created at: $OQS_CONF"

# Create environment setup script
echo "=== Creating environment setup script ==="
ENV_SCRIPT="$CONFIG_DIR/setup_env.sh"
cat > "$ENV_SCRIPT" << EOF
#!/bin/bash
# Environment setup for Open5GS with PQC support

export OPENSSL_CONF=$OQS_CONF
export OQS_OPENSSL_CONF=$OQS_CONF
export LD_LIBRARY_PATH=/usr/local/lib:\${LD_LIBRARY_PATH:-}
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:\${PKG_CONFIG_PATH:-}

echo "Open5GS PQC environment configured"
echo "Signature Algorithm: $SIGN_ALG"
echo "OQS Config: $OQS_CONF"
EOF
chmod +x "$ENV_SCRIPT"

echo ""
echo "=== Open5GS PQC configuration complete ==="
echo ""
echo "To start Open5GS with PQC support:"
echo "  source $CONFIG_DIR/setup_env.sh"
echo "  open5gs-nrfd"
echo "  open5gs-amfd"
echo "  ..."
echo ""
echo "Or use the experiment runner script:"
echo "  ./scripts/experiment/run_experiments.sh"
