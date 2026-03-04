# Providers matrix testing

This repo supports running functional tests against **provider combinations** aligned with the [llama-stack-distribution](https://github.com/opendatahub-io/llama-stack-distribution/tree/main/distribution) config.

## Provider dimensions

| Dimension    | Examples                    | Purpose                          |
|-------------|-----------------------------|----------------------------------|
| **files**   | `inline::localfs`, `remote::s3` | File storage backend             |
| **inference** | `remote::vllm`, `remote::azure`, `remote::bedrock`, … | Inference/chat/embedding backend |
| **vector_io** | `inline::milvus`, `remote::pgvector`, `remote::qdrant`, … | Vector store for RAG/agents      |

The full matrix is defined in **`config/providers-matrix.yaml`** (derived from [distribution/config.yaml](https://github.com/opendatahub-io/llama-stack-distribution/blob/main/distribution/config.yaml)).

## Running tests for a provider combination

1. **Deploy LLS** with the desired provider combination (files, inference, vector_io) and required env vars for each provider. This is outside this repo.

2. **Set test run variables** (and optionally provider labels for reporting):

   ```bash
   export BASE_URL="http://localhost:8321"
   export MODEL="your-model-name"                    # required for inference tests
   export FILES_PROVIDER="remote::s3"                 # optional, for reporting
   export INFERENCE_PROVIDER="remote::azure"         # optional
   export VECTOR_IO_PROVIDER="remote::pgvector"      # optional
   ```

   **Model** is required: every inference provider (vLLM, Azure, Bedrock, etc.) is tested with this model name.

3. **Run the full test run** (Bruno files + all Bruno collections + notebooks):

   ```bash
   ./local/scripts/run-tests-with-providers.sh
   ```

   Or build and run the **container** (same env vars): see `Containerfile` and README.

4. **What runs**

   - **Phase 1 – Bruno files**  
     Isolated endpoints for the Files API (upload, list, get, delete, etc.). Coverage is independent of inference/vector_io.

   - **Phase 2 – Bruno full**  
     All Bruno collections (chat completions, embeddings, agents, OpenResponses, etc.). These use `BASE_URL` and `MODEL`; inference provider is determined by how LLS is configured.

   - **Phase 3 – Notebooks**  
     Full-flow integration (responses API, MCP, agents, RAG). **Same parameters as Bruno:** the script exports env vars; notebooks read them via `config/notebook_env.py` (`os.environ.get`). See `notebooks/README.md`.

## Same parameters in notebooks (ipynb)

Bruno and notebooks share one parameter set:

- **Bruno:** gets `base_url`, `model`, and provider vars via `--env-var` from the script.
- **Notebooks:** the script exports the same env vars; the module `config/notebook_env` uses `os.environ.get` for each. In a notebook: `from config.notebook_env import base_url, model, inference_provider, files_provider, vector_io_provider`. See **`notebooks/README.md`** for path setup.

## Example: S3 + Azure + pgvector

```bash
export BASE_URL="https://my-lls.example.com"
export MODEL="gpt-4o"
export FILES_PROVIDER="remote::s3"
export INFERENCE_PROVIDER="remote::azure"
export VECTOR_IO_PROVIDER="remote::pgvector"
./local/scripts/run-tests-with-providers.sh
```

## CI / matrix runs

To test multiple combinations, call the script in a loop (or use a matrix in GitHub Actions) over `FILES_PROVIDER`, `INFERENCE_PROVIDER`, and `VECTOR_IO_PROVIDER`, with a single `MODEL` (or model per inference provider) and the same `BASE_URL` for each deployed stack.

**Container image:** Build from the repo `Containerfile` and run the image with the same env vars (`BASE_URL`, `MODEL`, and optional provider vars). The image runs `run-tests-with-providers.sh` as its entrypoint, so you can run it in any CI that supports containers.

## Reference

- Distribution config: [opendatahub-io/llama-stack-distribution/distribution](https://github.com/opendatahub-io/llama-stack-distribution/tree/main/distribution)
- Provider list and enablement: `distribution/README.md` and `distribution/config.yaml`
