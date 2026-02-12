#!/bin/bash
# entrypoint-relay.sh - Wrapper script for quiche-moq relay (moqt_relay)
# Translates standard MoQT interop environment variables to moqt_relay CLI flags
#
# Expected environment:
#   MOQT_ROLE     - Role to run: relay (required, only relay supported)
#   MOQT_PORT     - Port to listen on (default: 4443)
#   MOQT_CERT     - Path to TLS certificate (default: /certs/cert.pem)
#   MOQT_KEY      - Path to TLS private key (default: /certs/priv.key)
#
# Expected mounts:
#   /certs/cert.pem - TLS certificate chain (PEM)
#   /certs/priv.key - TLS private key (PKCS8 PEM)
#
# quiche moqt_relay CLI flags:
#   --certificate_file  Path to certificate chain (PEM)
#   --key_file          Path to PKCS8 private key (PEM)
#   --bind_address      Local IP to bind (default: 127.0.0.1)
#   --port              Port to listen on (default: 9667)
#
# Exit codes:
#   0   - Clean shutdown
#   1   - Configuration error
#   127 - Unsupported role

set -euo pipefail

ROLE="${MOQT_ROLE:-relay}"
PORT="${MOQT_PORT:-4443}"
CERT="${MOQT_CERT:-/certs/cert.pem}"
KEY="${MOQT_KEY:-/certs/priv.key}"

case "$ROLE" in
  relay)
    echo "Starting quiche-moq relay on port $PORT"
    echo "  Cert: $CERT"
    echo "  Key:  $KEY"

    if [ ! -f "$CERT" ]; then
      echo "ERROR: Certificate not found at $CERT" >&2
      echo "Make sure /certs is mounted with cert.pem and priv.key" >&2
      exit 1
    fi
    if [ ! -f "$KEY" ]; then
      echo "ERROR: Private key not found at $KEY" >&2
      exit 1
    fi

    exec /app/moqt_relay \
      --certificate_file "$CERT" \
      --key_file "$KEY" \
      --bind_address "0.0.0.0" \
      --port "$PORT"
    ;;

  *)
    echo "Role '$ROLE' not supported by quiche-moq adapter" >&2
    echo "Supported roles: relay" >&2
    exit 127
    ;;
esac
