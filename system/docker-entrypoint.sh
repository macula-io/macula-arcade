#!/bin/bash
set -e

# Default cert paths if not set
MACULA_CERT_PATH="${MACULA_CERT_PATH:-/opt/macula/certs/cert.pem}"
MACULA_KEY_PATH="${MACULA_KEY_PATH:-/opt/macula/certs/key.pem}"

# Generate self-signed TLS certificates if they don't exist
if [ ! -f "$MACULA_CERT_PATH" ] || [ ! -f "$MACULA_KEY_PATH" ]; then
    echo "[Entrypoint] Generating self-signed TLS certificates..."

    # Create certs directory if it doesn't exist (should already exist from Dockerfile)
    mkdir -p "$(dirname "$MACULA_CERT_PATH")" 2>/dev/null || true
    mkdir -p "$(dirname "$MACULA_KEY_PATH")" 2>/dev/null || true

    # Generate private key and certificate separately
    # Macula v0.8.5 uses separate cert and key files
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$MACULA_KEY_PATH" \
        -out "$MACULA_CERT_PATH" \
        -days 3650 \
        -subj "/CN=macula-node"

    # Set key permissions (600 = owner read/write only)
    chmod 600 "$MACULA_KEY_PATH"

    echo "[Entrypoint] Self-signed certificates generated at:"
    echo "[Entrypoint]   Cert: $MACULA_CERT_PATH"
    echo "[Entrypoint]   Key:  $MACULA_KEY_PATH"
else
    echo "[Entrypoint] TLS certificates found:"
    echo "[Entrypoint]   Cert: $MACULA_CERT_PATH"
    echo "[Entrypoint]   Key:  $MACULA_KEY_PATH"
fi

# Execute the main command
exec "$@"
