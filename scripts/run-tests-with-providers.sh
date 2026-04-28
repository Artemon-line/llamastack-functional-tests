#!/usr/bin/env bash
# shellcheck disable=SC1091
# Run Bruno CRUD and notebook tests for a given provider combination.
# Requires: BASE_URL, MODEL (inference model name).
# Optional: FILES_PROVIDER, INFERENCE_PROVIDER, VECTOR_IO_PROVIDER,
#           EMBEDDING_MODEL (for reporting/env).
#
# Example:
#   export BASE_URL="http://localhost:8321"
#   export MODEL="vllm-inference/llama-3-2-3b"
#   ./scripts/run-tests-with-providers.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRUNO_DIR="${REPO_ROOT}/bruno"
NOTEBOOKS_DIR="${REPO_ROOT}/notebooks"
REPORTS_DIR="${REPO_ROOT}/reports"
EXIT_CODE=0

mkdir -p "${REPORTS_DIR}"

if [[ -z "${BASE_URL:-}" ]]; then
  echo "Error: BASE_URL is required (e.g. http://localhost:8321)" >&2
  exit 1
fi
if [[ -z "${MODEL:-}" ]]; then
  echo "Error: MODEL is required for inference tests (e.g. vllm-inference/llama-3-2-3b)" >&2
  exit 1
fi

export FILES_PROVIDER="${FILES_PROVIDER:-}"
export INFERENCE_PROVIDER="${INFERENCE_PROVIDER:-}"
export VECTOR_IO_PROVIDER="${VECTOR_IO_PROVIDER:-}"
export EMBEDDING_MODEL="${EMBEDDING_MODEL:-}"

source "$(dirname "${BASH_SOURCE[0]}")/sync-client-version.sh"

# Health-check helper: verify the server is reachable, restart port-forward if needed
_ensure_server() {
  if curl -sf --connect-timeout 3 "${BASE_URL}/v1/health" >/dev/null 2>&1; then
    return 0
  fi
  echo "  Server unreachable at ${BASE_URL} — attempting port-forward restart..."
  pkill -f "port-forward.*lls-vllm-test" 2>/dev/null || true
  sleep 1
  local ns="${OC_NAMESPACE:-lls-vllm-test}"
  local svc="${OC_SERVICE:-svc/llama-stack-vllm-vertex-service}"
  local port="${BASE_URL##*:}"  # extract port from http://host:PORT
  oc port-forward -n "${ns}" "${svc}" "${port}:${port}" >/dev/null 2>&1 &
  sleep 4
  if curl -sf --connect-timeout 3 "${BASE_URL}/v1/health" >/dev/null 2>&1; then
    echo "  Port-forward restored"
    return 0
  fi
  echo "  Warning: could not restore connectivity to ${BASE_URL}" >&2
  return 1
}

echo ""
echo "=== Provider matrix test run ==="
echo "  BASE_URL           = ${BASE_URL}"
echo "  MODEL              = ${MODEL}"
echo "  EMBEDDING_MODEL    = ${EMBEDDING_MODEL}"
echo "  INFERENCE_PROVIDER = ${INFERENCE_PROVIDER}"
echo "  FILES_PROVIDER     = ${FILES_PROVIDER}"
echo "  VECTOR_IO_PROVIDER = ${VECTOR_IO_PROVIDER}"
echo ""

# ── Bruno CLI ────────────────────────────────────────────────────────────────
BRU=""
if [[ -x "${BRUNO_DIR}/node_modules/.bin/bru" ]]; then
  BRU="${BRUNO_DIR}/node_modules/.bin/bru"
elif command -v bru &>/dev/null; then
  BRU="bru"
elif command -v npx &>/dev/null; then
  BRU="npx --yes @usebruno/cli"
fi

_env_vars=(
  --env-var "baseUrl=${BASE_URL}"
  --env-var "model=${MODEL}"
  --env-var "inference_provider=${INFERENCE_PROVIDER}"
  --env-var "files_provider=${FILES_PROVIDER}"
  --env-var "vector_io_provider=${VECTOR_IO_PROVIDER}"
)

# ── Phase 1: Bruno CRUD tests ───────────────────────────────────────────────
LLS_CRUD_DIR="${BRUNO_DIR}/lls-crud"
if [[ -n "${BRU}" && -d "${LLS_CRUD_DIR}" ]]; then
  _ensure_server
  echo ">>> Phase 1: Bruno CRUD tests"
  _bruno_json=$(mktemp /tmp/bruno-results-XXXXXX.json)
  # Run Bruno; filter out proxy warnings and the misleading built-in summary
  if (cd "${LLS_CRUD_DIR}" && $BRU run . -r "${_env_vars[@]}" --output "${_bruno_json}") \
       2>&1 | grep -v -e "proxy" -e "Proxy" -e "getSystem" -e "at async" -e "at .*/node_modules/" -e "^$" \
              | sed '/📊 Execution Summary/,/└.*┘/d'; then
    :
  fi
  # Print accurate summary from JSON
  if [[ -s "${_bruno_json}" ]]; then
    if ! python3 "${REPO_ROOT}/scripts/bruno_summary.py" "${_bruno_json}" "${REPORTS_DIR}/bruno-crud.xml"; then
      EXIT_CODE=1
    fi
  else
    echo "  Warning: no Bruno JSON output produced"
    EXIT_CODE=1
  fi
  rm -f "${_bruno_json}"
  echo ""
else
  echo ">>> Phase 1: skipped (Bruno CLI not found)"
fi

# ── Phase 2: Notebooks ──────────────────────────────────────────────────────
if [[ -d "$NOTEBOOKS_DIR" ]]; then
  _ensure_server
  echo ">>> Phase 2: Notebooks — pytest"
  export BASE_URL MODEL FILES_PROVIDER INFERENCE_PROVIDER VECTOR_IO_PROVIDER EMBEDDING_MODEL
  export PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}"
  if ! (cd "$REPO_ROOT" && uv run pytest tests/test_notebooks.py -v --tb=short --junitxml="${REPORTS_DIR}/notebooks.xml"); then
    EXIT_CODE=1
  fi
  echo ""
fi

echo "=== Done (exit ${EXIT_CODE}) ==="
exit $EXIT_CODE
