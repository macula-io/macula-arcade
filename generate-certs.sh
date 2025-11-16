#!/bin/bash
# Generate self-signed certificates for Macula gateway
# For testing only - use proper CA-signed certs in production

CERT_DIR="system/priv/certs"
mkdir -p "$CERT_DIR"

# Generate private key
openssl genrsa -out "$CERT_DIR/server-key.pem" 2048

# Generate self-signed certificate with SAN extension
openssl req -new -x509 -key "$CERT_DIR/server-key.pem" \
  -out "$CERT_DIR/server-cert.pem" \
  -days 365 \
  -subj "/CN=macula-arcade-gateway/O=Macula Arcade/C=US" \
  -addext "subjectAltName=DNS:macula-arcade-gateway,DNS:localhost,IP:127.0.0.1"

echo "✓ Generated TLS certificates in $CERT_DIR"
ls -lh "$CERT_DIR"
