#!/usr/bin/env bash
set -euo pipefail

EXPECTED_NARGO_VERSION="nargo version = 1.0.0-beta.18"
ACTUAL_NARGO_VERSION="$(nargo --version | head -n 1)"

if [[ "${ACTUAL_NARGO_VERSION}" != "${EXPECTED_NARGO_VERSION}" ]]; then
  echo "Unsupported nargo version."
  echo "Expected: ${EXPECTED_NARGO_VERSION}"
  echo "Actual:   ${ACTUAL_NARGO_VERSION}"
  exit 1
fi

for pkg in position_commitment claim_reward; do
  echo "Checking circuits/${pkg}"
  (cd "circuits/${pkg}" && nargo check)
done

echo "Noir toolchain and circuit checks passed."
