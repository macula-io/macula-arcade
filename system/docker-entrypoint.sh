#!/bin/bash
set -e

# Generate self-signed TLS certificates if they don't exist
# Note: This runs as app user, so we need write permissions on /opt/macula/certs
if [ ! -f "/opt/macula/certs/cert.pem" ] || [ ! -f "/opt/macula/certs/key.pem" ]; then
    echo "Generating self-signed TLS certificates for local testing..."
    mkdir -p /opt/macula/certs

    openssl req -x509 -newkey rsa:4096 -nodes \
        -keyout /opt/macula/certs/key.pem \
        -out /opt/macula/certs/cert.pem \
        -days 365 \
        -subj "/CN=${PHX_HOST:-localhost}/O=Macula Arcade/C=US"

    echo "TLS certificates generated successfully"
fi

# Execute the original command
exec "$@"
