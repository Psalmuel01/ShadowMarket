#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "Usage: $0 <verifier_address> [position_program_hash] [claim_program_hash]"
  echo "If hashes are omitted, they are loaded from circuits/program_hashes.env."
  exit 1
fi

VERIFIER_ADDRESS="$1"

if [[ $# -eq 3 ]]; then
  POSITION_PROGRAM_HASH="$2"
  CLAIM_PROGRAM_HASH="$3"
else
  ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
  HASH_FILE="${ROOT_DIR}/circuits/program_hashes.env"
  if [[ ! -f "${HASH_FILE}" ]]; then
    echo "Missing ${HASH_FILE}. Run ./scripts/compile_circuits.sh first."
    exit 1
  fi
  # shellcheck source=/dev/null
  source "${HASH_FILE}"
fi

# Requires sncast profile configuration in snfoundry.toml.
sncast invoke \
  --contract-address "${VERIFIER_ADDRESS}" \
  --function set_program_hash \
  --calldata "${POSITION_PROGRAM_HASH}" "1"

sncast invoke \
  --contract-address "${VERIFIER_ADDRESS}" \
  --function set_program_hash \
  --calldata "${CLAIM_PROGRAM_HASH}" "1"

echo "Registered program hashes in verifier ${VERIFIER_ADDRESS}."
