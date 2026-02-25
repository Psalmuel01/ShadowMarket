#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POSITION_DIR="${ROOT_DIR}/circuits/position_commitment"
CLAIM_DIR="${ROOT_DIR}/circuits/claim_reward"

(cd "${POSITION_DIR}" && nargo compile)
(cd "${CLAIM_DIR}" && nargo compile)

POSITION_ARTIFACT="${POSITION_DIR}/target/position_commitment.json"
CLAIM_ARTIFACT="${CLAIM_DIR}/target/claim_reward.json"

POSITION_PROGRAM_HASH="$(sed -n 's/.*"hash":"\([^"]*\)".*/\1/p' "${POSITION_ARTIFACT}")"
CLAIM_PROGRAM_HASH="$(sed -n 's/.*"hash":"\([^"]*\)".*/\1/p' "${CLAIM_ARTIFACT}")"

if [[ -z "${POSITION_PROGRAM_HASH}" || -z "${CLAIM_PROGRAM_HASH}" ]]; then
  echo "Failed to parse program hashes from Noir artifacts."
  exit 1
fi

OUTPUT_FILE="${ROOT_DIR}/circuits/program_hashes.env"
cat > "${OUTPUT_FILE}" <<EOF
# Generated from Noir artifact metadata (`hash` field).
POSITION_PROGRAM_HASH=${POSITION_PROGRAM_HASH}
CLAIM_PROGRAM_HASH=${CLAIM_PROGRAM_HASH}
EOF

echo "Wrote ${OUTPUT_FILE}"
echo "POSITION_PROGRAM_HASH=${POSITION_PROGRAM_HASH}"
echo "CLAIM_PROGRAM_HASH=${CLAIM_PROGRAM_HASH}"
