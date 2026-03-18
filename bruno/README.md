# Bruno collections

- **Environment:** `environments/lls.bru` — set `base_url` (default `http://localhost:8321` for LLS 0.2.22.2+rhai0), `model` (inference model name), `inference_provider`, `files_provider`, `vector_io_provider`.
- **Model:** All inference requests (chat completions, embeddings, etc.) must use the `model` variable so each inference provider (vLLM, Azure, Bedrock, etc.) is tested with the same model name. Set `MODEL` when running via CLI or the provider-matrix script.
- **Provider-matrix runs:** Use `./scripts/run-tests-with-providers.sh` (or the container image) with `BASE_URL`, `MODEL`, and optional `FILES_PROVIDER`, `INFERENCE_PROVIDER`, `VECTOR_IO_PROVIDER`. See `docs/providers-matrix.md` and `config/providers-matrix.yaml`.
- **Layout:** Put collections directly under `bruno/` (e.g. `files/`, `lls-crud/`, `lls-api/`). Version-specific state lives on **git branches**, not in version folders. The script runs `bruno/files` (isolated Files API) then all of `bruno/`.

## Generating tests from OpenAPI

To generate a Bruno collection from the LLS OpenAPI spec:

**Option A — use a local spec (e.g. from a running server):**  
Place the spec at `bruno/openapi.json`, then run:

```bash
./bruno/scripts/generate-from-openapi.sh
```

**Option B — fetch from running LLS:**  
With the server up at `BASE_URL`:

```bash
export BASE_URL="http://localhost:8321"
./bruno/scripts/generate-from-openapi.sh
```

This uses `bruno/openapi.json` if present; otherwise fetches `{BASE_URL}/openapi.json` into `bruno/spec/openapi.json`. Then runs `bru import openapi` into `bruno/lls-api`. Requires `bru` CLI (`npm i -g @usebruno/cli`).

## LLS CRUD collection (`lls-crud/`)

The **lls-crud** collection provides CRUD tests with **assertions** and **variable handling** for LLS 0.2.22.2:

- **01-version** — GET `/v1/version` (assert status and version present).
- **02-models** — GET `/v1/models`.
- **03-providers** — GET `/v1/providers`.
- **04-files** — Create (POST), List, Get by `file_id`, Delete. `file_id` is set from Create and used in Get/Delete.
- **05-vector-stores** — Create (POST), List, Get by `vector_store_id`, Delete. `vector_store_id` is set from Create and used in Get/Delete.
- **06-responses** — POST `/v1/responses` (uses `{{model}}` from env).

Run CRUD tests with env and optional overrides:

```bash
bru run bruno/lls-crud --env-file bruno/environments/lls.bru --env-var base_url=http://localhost:8321 --env-var model=your-model-id
```

For **Files** CRUD, run **Create File** first (attach a file in Bruno or provide a path) so `file_id` is set for Get/Delete. For **Vector Stores**, run **Create Vector Store** first so `vector_store_id` is set.
