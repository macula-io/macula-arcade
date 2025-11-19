#!/bin/sh
# Macula Arcade Entrypoint Script
# Starts both the Macula mesh gateway and Phoenix web server

set -e

echo "Starting Macula Arcade..."
echo "Gateway mode: ${MACULA_START_GATEWAY:-false}"
echo "Realm: ${MACULA_REALM:-macula.arcade}"
echo "Port: ${PORT:-4000}"

# Start the Elixir release
# This will start both macula_arcade and macula_arcade_web applications
exec bin/macula_arcade start
