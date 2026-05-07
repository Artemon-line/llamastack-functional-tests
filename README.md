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

- **Full plan and layout:** [OGX_FUNCTIONAL_TESTS_PLAN.md](OGX_FUNCTIONAL_TESTS_PLAN.md)
- **Provider matrix:** [docs/providers-matrix.md](docs/providers-matrix.md) and [config/providers-matrix.yaml](config/providers-matrix.yaml) (aligned with [ogx-distribution/distribution](https://github.com/opendatahub-io/ogx-distribution/tree/main/distribution))

## Test run phases

1. **Bruno ogx-api** — generated from OpenAPI, covers all OGX endpoints (`bruno/ogx-api`)
2. **Bruno full** — all collections under `bruno/`
3. **Notebooks** — run as **pytest** tests (each notebook in `notebooks/` executed to completion; see [notebooks/README.md](notebooks/README.md) and [Jupyter Notebooks as Test Cases](https://blog.iqmo.com/blog/python/jupyter_notebook_testing/))

Each **inference** provider is tested with the **model** you set (`MODEL`). For notebook tests locally, install deps: `pip install -r requirements-test.txt`.
