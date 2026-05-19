# OGX Functional Tests

Functional tests for OGX (Bruno + notebooks). The server is assumed **running**; you provide **BASE_URL** and **model name**.

## Quick start (local)

### 1. Generate Bruno collection from your running server

```bash
# Install Bruno CLI (one-time)
cd bruno && npm install && cd ..

# Generate ogx-api collection from OpenAPI spec
./bruno/scripts/generate-from-openapi.sh
```

### 2. Run all Bruno tests

```bash
npx --prefix bruno bru run bruno/ogx-api \
  --env-file bruno/environments/ogx.bru \
  --env-var base_url=http://localhost:8321 \
  --env-var model=vllm-inference/llama-3-2-3b
```

### 3. Provider-matrix runs (all phases)

```bash
export BASE_URL="http://localhost:8321"
export MODEL="vllm-inference/llama-3-2-3b"
# Optional:
export FILES_PROVIDER="remote::s3"
export INFERENCE_PROVIDER="remote::azure"
export VECTOR_IO_PROVIDER="remote::pgvector"

./scripts/run-tests-with-providers.sh
```

## Run in CI / elsewhere (container)

Build the image and run with the **same env vars**:

```bash
podman build -t ogx-functional-tests -f Containerfile .
podman run --rm \
  -e BASE_URL="http://ogx:8321" \
  -e MODEL="vllm-inference/llama-3-2-3b" \
  -e FILES_PROVIDER="remote::s3" \
  -e INFERENCE_PROVIDER="remote::azure" \
  -e VECTOR_IO_PROVIDER="remote::pgvector" \
  ogx-functional-tests
```

**Required:** `BASE_URL`, `MODEL`. **Optional:** `FILES_PROVIDER`, `INFERENCE_PROVIDER`, `VECTOR_IO_PROVIDER`.

## Environment variables reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BASE_URL` | Yes | — | OGX server URL (e.g. `http://localhost:8321`) |
| `MODEL` | Yes | — | Inference model name (e.g. `Qwen/Qwen3-0.6B`) |
| `EMBEDDING_MODEL` | No | `""` | Embedding model name |
| `EMBEDDING_DIMENSION` | No | — | Embedding vector dimension (must match model) |
| `FILES_PROVIDER` | No | `""` | Files provider override |
| `INFERENCE_PROVIDER` | No | `""` | Inference provider override |
| `VECTOR_IO_PROVIDER` | No | `""` | Vector IO provider override |
| `HEALTH_CHECK_TIMEOUT` | No | `0` | Seconds to wait for server health before running tests. `0` = skip (local dev). Set to e.g. `600` in CI where sidecars need time to start. Uses exponential backoff (2s → 15s cap). |
| `SKIP_CLIENT_SYNC` | No | `0` | Set to `1` to skip `sync-client-version.sh`. Use in CI when the branch already pins the correct `ogx-client` in `pyproject.toml` — avoids runtime PyPI access. |
| `OC_NAMESPACE` | No | `ogx-vllm-test` | OpenShift namespace for port-forward fallback. Set to empty string to disable port-forward (e.g. in Tekton where `oc` is not available). |

- **Full plan and layout:** [OGX_FUNCTIONAL_TESTS_PLAN.md](OGX_FUNCTIONAL_TESTS_PLAN.md)
- **Provider matrix:** [docs/providers-matrix.md](docs/providers-matrix.md) and [config/providers-matrix.yaml](config/providers-matrix.yaml) (aligned with [ogx-distribution/distribution](https://github.com/opendatahub-io/ogx-distribution/tree/main/distribution))

## Test run phases

1. **Bruno ogx-api** — generated from OpenAPI, covers all OGX endpoints (`bruno/ogx-api`)
2. **Bruno full** — all collections under `bruno/`
3. **Notebooks** — run as **pytest** tests (each notebook in `notebooks/` executed to completion; see [notebooks/README.md](notebooks/README.md) and [Jupyter Notebooks as Test Cases](https://blog.iqmo.com/blog/python/jupyter_notebook_testing/))

Each **inference** provider is tested with the **model** you set (`MODEL`). For notebook tests locally, install deps: `pip install -r requirements-test.txt`.
