#!/usr/bin/env bash
# Generate a self-signed TLS keypair on disk only (no kubectl). Use this to try the openssl
# options before building a Kubernetes Secret with create-tls-secret.sh.
#
# Usage:
#   ./generate-tls-local.sh
#   OUT_DIR=./my-certs TLS_CN=sip.example.com ./generate-tls-local.sh
#
# Environment:
#   OUT_DIR       Directory for tls.key and tls.crt (default: ./tls-local)
#   TLS_CN        Certificate CN / primary DNS SAN (default: sip.example.com)
#   TLS_SAN_DNS   subjectAltName DNS value (default: same as TLS_CN)
#   DAYS          Validity in days (default: 3650)

set -euo pipefail

OUT_DIR="${OUT_DIR:-./tls-local}"
TLS_CN="${TLS_CN:-sip.example.com}"
TLS_SAN_DNS="${TLS_SAN_DNS:-$TLS_CN}"
DAYS="${DAYS:-3650}"

usage() {
    echo "Usage: $0"
    echo "Writes tls.key and tls.crt under OUT_DIR (default: ./tls-local). See script header for env vars."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl not found in PATH" >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"
KEY="${OUT_DIR}/tls.key"
CRT="${OUT_DIR}/tls.crt"

openssl req -x509 -newkey rsa:4096 -sha256 -days "${DAYS}" -nodes \
    -keyout "${KEY}" -out "${CRT}" \
    -subj "/CN=${TLS_CN}" \
    -addext "subjectAltName=DNS:${TLS_SAN_DNS}"

echo "Wrote:"
echo "  ${KEY}"
echo "  ${CRT}"
