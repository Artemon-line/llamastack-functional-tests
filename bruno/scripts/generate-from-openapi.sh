
#!/usr/bin/env bash
# Fetch OpenAPI spec from running LLS (e.g. 0.2.22.2+rhai0) and generate Bruno collection.
# Usage: BASE_URL=http://localhost:8321 ./bruno/scripts/generate-from-openapi.sh
# Requires: curl, bru (Bruno CLI). Optional: BASE_URL (default: http://localhost:8321).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRUNO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${BRUNO_DIR}/.." && pwd)"
SPEC_URL="${BASE_URL:-http://localhost:8321}/openapi.json"
OUTPUT_COLLECTION="${BRUNO_DIR}/lls-api"
SPEC_FILE_LOCAL="${BRUNO_DIR}/openapi.json"
SPEC_FILE_FETCHED="${BRUNO_DIR}/spec/openapi.json"
COLLECTION_NAME="LLS API"

echo "=== Generate Bruno collection from LLS OpenAPI ==="
echo "OUTPUT_COLLECTION=${OUTPUT_COLLECTION}"
echo ""

# Use local bruno/openapi.json if present; otherwise fetch from server
if [[ -f "${SPEC_FILE_LOCAL}" ]]; then
  SPEC_FILE="${SPEC_FILE_LOCAL}"
  echo "Using local spec: ${SPEC_FILE}"
else
  mkdir -p "${BRUNO_DIR}/spec"
  SPEC_FILE="${SPEC_FILE_FETCHED}"
  if curl -sf --connect-timeout 5 "${SPEC_URL}" -o "${SPEC_FILE}"; then
    echo "Fetched OpenAPI spec to ${SPEC_FILE}"
  else
    echo "Error: No local spec at ${SPEC_FILE_LOCAL} and could not fetch from ${SPEC_URL}. Save openapi.json to bruno/openapi.json or ensure LLS is running." >&2
    exit 1
  fi
fi

# Bruno CLI — prefer local node_modules, then global, then npx
if [[ -x "${REPO_ROOT}/bruno/node_modules/.bin/bru" ]]; then
  BRU="${REPO_ROOT}/bruno/node_modules/.bin/bru"
elif command -v bru &>/dev/null; then
  BRU="bru"
elif command -v npx &>/dev/null; then
  BRU="npx --yes @usebruno/cli"
else
  echo "Error: 'bru' (Bruno CLI) not found. Install: npm i -g @usebruno/cli or run 'npm install' in bruno/" >&2
  exit 1
fi
echo "Using bru: ${BRU}"

mkdir -p "$(dirname "${OUTPUT_COLLECTION}")"
$BRU import openapi \
  --source "${SPEC_FILE}" \
  --output "${OUTPUT_COLLECTION}" \
  --collection-name "${COLLECTION_NAME}" \
  || { echo "Error: bru import failed" >&2; exit 1; }

echo "Collection written to ${OUTPUT_COLLECTION}"
echo "Run with: bru run ${OUTPUT_COLLECTION} --env-file ${BRUNO_DIR}/environments/lls.bru --env-var base_url=${BASE_URL:-http://localhost:8321} --env-var model=\${MODEL}"
echo "=== Done ==="
