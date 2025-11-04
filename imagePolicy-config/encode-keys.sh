#!/bin/bash

# Script to base64 encode public keys for ImagePolicy configuration

echo "Encoding public keys..."

# Encode Rekor public key
REKOR_B64=$(base64 -w 0 rekor-public-key.pem)
echo "Rekor Public Key (base64):"
echo "$REKOR_B64"
echo ""

# Encode Signer public key
SIGNER_B64=$(base64 -w 0 signer-public-key.pem)
echo "Signer Public Key (base64):"
echo "$SIGNER_B64"
echo ""

echo "Keys encoded successfully!"
echo ""
echo "You can now use these base64-encoded values in your ImagePolicy YAML."
