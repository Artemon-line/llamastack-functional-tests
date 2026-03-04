#!/usr/bin/env bash
# Run Bruno (files + full) and notebooks for a given provider combination.
# Requires: BASE_URL, MODEL (inference model name).
# Optional: FILES_PROVIDER, INFERENCE_PROVIDER, VECTOR_IO_PROVIDER (for reporting/env).
#
# Example:
#   export BASE_URL="http://localhost:8321"
#   export MODEL="my-model"
#   export FILES_PROVIDER="remote::s3"
#   export INFERENCE_PROVIDER="remote::azure"
#   export VECTOR_IO_PROVIDER="remote::pgvector"
#   ./local/scripts/run-tests-with-providers.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRUNO_DIR="${REPO_ROOT}/bruno"
NOTEBOOKS_DIR="${REPO_ROOT}/notebooks"
ENV_NAME="lls"

# Required
if [[ -z "${BASE_URL}" ]]; then
  echo "Error: BASE_URL is required (e.g. http://localhost:8321)" >&2
  exit 1
fi
if [[ -z "${MODEL}" ]]; then
  echo "Error: MODEL is required for inference tests (e.g. your deployment model name)" >&2
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

# Build Bruno env-var overrides so base_url and model (and optional provider labels) are set
_env_vars=(
  --env-var "base_url=${BASE_URL}"
  --env-var "model=${MODEL}"
  --env-var "inference_provider=${INFERENCE_PROVIDER}"
  --env-var "files_provider=${FILES_PROVIDER}"
  --env-var "vector_io_provider=${VECTOR_IO_PROVIDER}"
)

ENV_FILE="${BRUNO_DIR}/environments/lls.bru"
cd "$REPO_ROOT"

# Phase 1: Bruno files (isolated Files API endpoints)
if [[ -d "${BRUNO_DIR}/files" ]]; then
  echo ">>> Phase 1: Bruno files (isolated endpoints)"
  if command -v bru &>/dev/null; then
    bru run "${BRUNO_DIR}/files" --env-file "$ENV_FILE" "${_env_vars[@]}" || exit 1
  else
    echo "Warning: 'bru' not found; skipping Bruno. Install Bruno CLI: npm i -g @usebruno/cli" >&2
  fi
else
  echo ">>> Phase 1: Bruno files folder not found at ${BRUNO_DIR}/files; skipping."
fi

# Phase 2: Bruno full (all collections)
echo ">>> Phase 2: Bruno full (all collections)"
if [[ -d "$BRUNO_DIR" ]] && command -v bru &>/dev/null; then
  bru run "$BRUNO_DIR" --env-file "$ENV_FILE" "${_env_vars[@]}" || exit 1
else
  echo "Warning: Bruno dir not found or 'bru' not installed; skipping."
fi

# Phase 3: Notebooks (full-flow integration) — run as pytest tests (ExecutePreprocessor)
# Notebooks read same params from env via config/notebook_env.py (os.environ.get).
# See: https://blog.iqmo.com/blog/python/jupyter_notebook_testing/
if [[ -d "$NOTEBOOKS_DIR" ]]; then
  echo ">>> Phase 3: Notebooks (full flow) — pytest"
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
  echo ">>> Phase 3: No notebooks at ${NOTEBOOKS_DIR}; skipping."
fi

echo "=== Done ==="
