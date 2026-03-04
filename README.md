# LlamaStack Functional Tests

Functional tests for LlamaStack (Bruno + notebooks). LLS is assumed **running**; you provide **BASE_URL** and **model name**.

## Quick start (local)

```bash
export BASE_URL="http://localhost:8321"
export MODEL="your-model-name"
# Optional, for provider-matrix runs:
export FILES_PROVIDER="remote::s3"
export INFERENCE_PROVIDER="remote::azure"
export VECTOR_IO_PROVIDER="remote::pgvector"

./scripts/run-tests-with-providers.sh
```

## Run in CI / elsewhere (container)

Build the image and run with the **same env vars**:

```bash
podman build -t llamastack-functional-tests -f Containerfile .
podman run --rm \
  -e BASE_URL="http://lls:8321" \
  -e MODEL="my-model" \
  -e FILES_PROVIDER="remote::s3" \
  -e INFERENCE_PROVIDER="remote::azure" \
  -e VECTOR_IO_PROVIDER="remote::pgvector" \
  llamastack-functional-tests
```

**Required:** `BASE_URL`, `MODEL`. **Optional:** `FILES_PROVIDER`, `INFERENCE_PROVIDER`, `VECTOR_IO_PROVIDER`.

- **Full plan and layout:** [LLS_FUNCTIONAL_TESTS_PLAN.md](LLS_FUNCTIONAL_TESTS_PLAN.md)
- **Provider matrix:** [docs/providers-matrix.md](docs/providers-matrix.md) and [config/providers-matrix.yaml](config/providers-matrix.yaml) (aligned with [llama-stack-distribution/distribution](https://github.com/opendatahub-io/llama-stack-distribution/tree/main/distribution))

## Test run phases

1. **Bruno files** — isolated Files API endpoints (`bruno/files`)
2. **Bruno full** — all collections under `bruno/`
3. **Notebooks** — run as **pytest** tests (each notebook in `notebooks/` executed to completion; see [notebooks/README.md](notebooks/README.md) and [Jupyter Notebooks as Test Cases](https://blog.iqmo.com/blog/python/jupyter_notebook_testing/))

Each **inference** provider is tested with the **model** you set (`MODEL`). For notebook tests locally, install deps: `pip install -r requirements-test.txt`.
