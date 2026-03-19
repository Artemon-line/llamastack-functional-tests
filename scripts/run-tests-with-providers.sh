#!/usr/bin/env bash
# Run Bruno (files + full) and notebooks for a given provider combination.
# Requires: BASE_URL, MODEL (inference model name).
# Optional: FILES_PROVIDER, INFERENCE_PROVIDER, VECTOR_IO_PROVIDER (for reporting/env).
#
# Example:
#   export BASE_URL="http://localhost:8321"
#   export MODEL="vllm-inference/llama-3-2-3b"
#   ./scripts/run-tests-with-providers.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRUNO_DIR="${REPO_ROOT}/bruno"
NOTEBOOKS_DIR="${REPO_ROOT}/notebooks"

# Required
if [[ -z "${BASE_URL}" ]]; then
  echo "Error: BASE_URL is required (e.g. http://localhost:8321)" >&2
  exit 1
fi
if [[ -z "${MODEL}" ]]; then
  echo "Error: MODEL is required for inference tests (e.g. vllm-inference/llama-3-2-3b)" >&2
  exit 1
fi

# Optional provider labels (for env and reporting)
export FILES_PROVIDER="${FILES_PROVIDER:-}"
export INFERENCE_PROVIDER="${INFERENCE_PROVIDER:-}"
export VECTOR_IO_PROVIDER="${VECTOR_IO_PROVIDER:-}"

echo "=== Provider matrix test run ==="
echo "BASE_URL=${BASE_URL}"
echo "MODEL=${MODEL}"
echo "FILES_PROVIDER=${FILES_PROVIDER}"
echo "INFERENCE_PROVIDER=${INFERENCE_PROVIDER}"
echo "VECTOR_IO_PROVIDER=${VECTOR_IO_PROVIDER}"
echo ""

# Resolve bru CLI — prefer local node_modules, then global, then npx
if [[ -x "${BRUNO_DIR}/node_modules/.bin/bru" ]]; then
  BRU="${BRUNO_DIR}/node_modules/.bin/bru"
elif command -v bru &>/dev/null; then
  BRU="bru"
elif command -v npx &>/dev/null; then
  BRU="npx --yes @usebruno/cli"
else
  echo "Error: 'bru' (Bruno CLI) not found. Install: npm i -g @usebruno/cli or run 'npm install' in bruno/" >&2
  exit 1
fi
echo "Using bru: ${BRU}"

# Bruno env-var overrides (baseUrl is camelCase to match generated collections)
_env_vars=(
  --env-var "baseUrl=${BASE_URL}"
  --env-var "model=${MODEL}"
  --env-var "inference_provider=${INFERENCE_PROVIDER}"
  --env-var "files_provider=${FILES_PROVIDER}"
  --env-var "vector_io_provider=${VECTOR_IO_PROVIDER}"
)

# Phase 1: Bruno lls-api (generated from OpenAPI, all endpoints)
LLS_API_DIR="${BRUNO_DIR}/lls-api"
if [[ -d "${LLS_API_DIR}" ]]; then
  echo ">>> Phase 1: Bruno lls-api (all endpoints, recursive)"
  (cd "${LLS_API_DIR}" && $BRU run . -r "${_env_vars[@]}") || exit 1
else
  echo ">>> Phase 1: lls-api collection not found at ${LLS_API_DIR}; generate with ./bruno/scripts/generate-from-openapi.sh"
fi

# Phase 2: Notebooks (full-flow integration) — run as pytest tests (ExecutePreprocessor)
if [[ -d "$NOTEBOOKS_DIR" ]]; then
  echo ">>> Phase 2: Notebooks (full flow) — pytest"
  export BASE_URL MODEL FILES_PROVIDER INFERENCE_PROVIDER VECTOR_IO_PROVIDER
  export PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}"
  if command -v pytest &>/dev/null; then
    (cd "$REPO_ROOT" && pytest tests/test_notebooks.py -v) || exit 1
  elif command -v jupyter &>/dev/null; then
    echo "Fallback: jupyter nbconvert (install pytest, nbformat, nbconvert for pytest-based runs)"
    for nb in "$NOTEBOOKS_DIR"/*.ipynb; do
      [[ -f "$nb" ]] || continue
      echo "Executing $nb"
      jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=300 "$nb" || exit 1
    done
  else
    echo "Warning: neither 'pytest' nor 'jupyter' found; skipping notebooks. Install: pip install -r requirements-test.txt" >&2
  fi
else
  echo ">>> Phase 2: No notebooks at ${NOTEBOOKS_DIR}; skipping."
fi

echo "=== Done ==="
