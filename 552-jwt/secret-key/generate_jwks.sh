#!/bin/bash
# Usage: ./generate_jwks.sh <public_key_file> <output_jwks.json> <kid>
# Generates a proper JWKS JSON from an RSA public key

if [ $# -ne 3 ]; then
  echo "Usage: $0 <public_key_file> <output_jwks.json> <kid>"
  exit 1
fi

PUBKEY_FILE="$1"
JWKS_FILE="$2"
KID="$3"

# -----------------------------
# Base64URL encoding function
b64url_encode() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

# -----------------------------
# Extract modulus (n) in hex
N_HEX=$(openssl rsa -in "$PUBKEY_FILE" -pubin -text -noout \
  | awk '/Modulus:/{flag=1;next}/Exponent:/{flag=0}flag' \
  | tr -d ' \n:')

# Convert modulus to binary and Base64URL encode
N_B64=$(echo "$N_HEX" | xxd -r -p | b64url_encode)

# -----------------------------
# Extract exponent (e) in decimal
E_DEC=$(openssl rsa -in "$PUBKEY_FILE" -pubin -text -noout \
  | awk '/Exponent:/{print $2}')

# Convert exponent to big-endian hex with minimum bytes
# This ensures proper Base64URL encoding
E_HEX=$(printf '%x\n' "$E_DEC")
# If length is odd, prepend 0
[[ $((${#E_HEX} % 2)) -ne 0 ]] && E_HEX="0$E_HEX"

# Convert to binary and Base64URL encode
E_B64=$(echo "$E_HEX" | xxd -r -p | b64url_encode)

# -----------------------------
# Generate JWKS JSON
cat <<EOF > "$JWKS_FILE"
{
  "keys": [
    {
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "kid": "$KID",
      "n": "$N_B64",
      "e": "$E_B64"
    }
  ]
}
EOF

echo "JWKS file generated: $JWKS_FILE"
