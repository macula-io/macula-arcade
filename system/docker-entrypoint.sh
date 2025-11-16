#!/bin/bash
set -e

# Generate self-signed TLS certificates if they don't exist
if [ ! -f "$MACULA_CERT_PATH" ] || [ ! -f "$MACULA_KEY_PATH" ]; then
    echo "[Entrypoint] Generating self-signed TLS certificates..."

    # Create certs directory if it doesn't exist
    mkdir -p "$(dirname "$MACULA_CERT_PATH")"
    mkdir -p "$(dirname "$MACULA_KEY_PATH")"

    # Generate private key and certificate
    openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout "$MACULA_KEY_PATH" \
        -out "$MACULA_CERT_PATH" \
        -days 365 \
        -subj "/C=US/ST=State/L=City/O=Macula/CN=localhost"

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
