# Plan: LlamaStack Functional Testing Repository

A single repository for **functional testing** of LlamaStack (complementary to [openshift-psap/llamastack-performance](https://github.com/openshift-psap/llamastack-performance), which focuses on performance/benchmarking). Goals: **all tests in one place**, **simple execution** (Bruno, notebooks). Version-specific test state is isolated via **git branches** (no version folders in the tree).

**Assumption:** LLS is **running and in working condition**. The user (or CI) provides **base URL** and **model name** (e.g. vLLM) to test against; no multiple environments (staging vs CI vs local)—**one Bruno env** with `base_url` and `model`.

---

## 1. What You Have Today (Summary)

### 1.1 Bruno collections (`code/Bruno_collections/`)

| Collection | Purpose |
|-----------|--------|
| **OpenResoponser_Acceptance_Tests** | OpenResponses compliance: Basic Text, Streaming, System Prompt, Tool Calling, Image Input, Multi-turn. Uses `script:post-response` assertions. |
| **Inference Chat Completions Comprehensive Tests** | Chat/Completion CRUD, streaming, system message, conversation operations. |
| **Openai Embeddings** | Create embedding, encoding format, edge cases (empty, invalid model, missing input, etc.). |
| **Postgres Agents Comprehensive Tests** | Responses API with Postgres: Create Model Response, Get Response Status, Conversation CRUD. |
| **RHOAI-Upgrade-2-25-to-3** | Upgrade testing: Get Providers, completions on 2.25 vs 3. |

Environments use `base_url` (e.g. `http://localhost:8321`), `model`, `api_key`.

### 1.2 Notebooks (`code/LLS_NoteBooks/`)

- **Release_Testing/responses-api.ipynb** – Responses API + MCP tool calling (with Random Word Generator).
- **MCP/** – `lls_mcp_usage_testing.ipynb`, `mcp_server_random_word_generator.py`, README.
- **test_lls_agent.ipynb**, **test_lls_agentic_session_test.ipynb**, **test_lls_rag_agent_with_embeddings.ipynb** – agent/agentic/RAG tests.
- **test_aws_bedrock.ipynb**, **bedrock_inference_example (2).ipynb** – Bedrock inference (optional for repo).

### 1.3 Local run scripts (`code/Configs/`)

- **run-postgres-podman.sh** – PostgreSQL in Podman (network `llama-telemetry`, volume, optional cleanup).
- **run-llama-stack-podman.sh** – LlamaStack container, Postgres-backed, health check on `/v1/health`.

### 1.4 Other under `code/`

- **Configs/** – Many cluster/deploy YAMLs (UPGRADE, LLS_POSTGRESS, vLLM, etc.). Only a **minimal subset** should move (e.g. one example `run.yaml` or LLS CR for CI).
- **FORKS/llama-stack-1**, **llama-stack**, **__learning**, **langgraph-agents-example** – Keep where they are; reference them from the new repo if needed; do **not** copy wholesale.

---

## 2. Proposed Repository Layout

Mirror the clarity of `llamastack-performance` (e.g. `agentic/`, `benchmarking/`, README per area) but oriented to **functional** tests and **local + CI**:

```
llamastack-functional-tests/
├── README.md                   # Overview, prerequisites, quick start (URL + model), test matrix
├── Containerfile                # Image to run tests in CI with same env vars
├── .github/
│   └── workflows/
│       └── functional-tests.yml   # Optional: run Bruno against LLS (BASE_URL + model from env/secrets)
├── docs/
│   ├── test-matrix.md          # Feature → collection / notebook map
│   ├── openapi-driven-tests.md # API spec → Bruno (§9)
│   ├── local-podman.md
│   ├── bruno-cli.md
│   └── openresponses-compliance.md
├── bruno/
│   ├── README.md               # How to run (GUI + CLI); user provides base_url + model
│   ├── environments/
│   │   └── lls.bru             # Single env: base_url, model (e.g. vllm), api_key
│   ├── files/                  # Files API (isolated endpoints)
│   ├── openresponses-acceptance/
│   ├── chat-completions/
│   ├── embeddings/
│   ├── postgres-agents/
│   ├── upgrade/
│   ├── generated/              # Optional: from OpenAPI
│   └── scripts/
│       └── generate-from-openapi.sh
├── notebooks/
│   ├── README.md               # deps; set BASE_URL + model in env or notebook
│   ├── *.ipynb                 # Notebooks (run as pytest tests)
│   ├── mcp/
│   ├── agents/
│   └── inference/
├── local/                      # Optional: how to run LLS locally (Podman/Compose)
│   ├── README.md
│   ├── podman/
│   │   ├── run-postgres-podman.sh
│   │   └── run-llama-stack-podman.sh
│   ├── docker-compose.yml     # Optional
│   └── scripts/
│       ├── run-bruno-local.sh # Bruno run; expects LLS up, BASE_URL + model in env
│       └── check-health.sh
├── ci/
│   ├── README.md
│   └── scripts/
│       └── run-bruno-ci.sh    # Run Bruno; BASE_URL + model from env
└── configs/
    ├── README.md
    └── run.yaml.example       # Optional
```

---

## 3. What to Move vs Leave

### Move into the new repo

- **Bruno:** All collections directly under `bruno/` (e.g. `files/`, `openresponses-acceptance/`); normalize folder names (e.g. `OpenResoponser_Acceptance_Tests` → `openresponses-acceptance`). One shared `environments/lls.bru` with `base_url` and `model` (vllm); user provides these. Version-specific state lives on **git branches**, not in version folders.
- **Notebooks:** Directly under `notebooks/`; copy from LLS_NoteBooks as above. User sets BASE_URL and model (env or in notebook).
- **Local scripts:** Optional; into `local/podman/` and `local/scripts/`. Assume LLS is running; scripts run Bruno/notebooks against provided URL + model.
- **Configs:** Minimal (e.g. `run.yaml.example`) only if needed for local run docs.

### Leave in place (or reference)

- **FORKS/llama-stack-1**, **llama-stack**, **__learning**, **langgraph-agents-example** – reference in README; don’t duplicate.
- **Configs/** – All cluster-specific YAMLs (UPGRADE backups, LLS_POSTGRESS, vLLM, etc.); document “point your cluster/configs elsewhere” for non-local runs.

---

## 4. Execution (LLS assumed running)

**User provides:** `base_url` (e.g. `http://localhost:8321`) and `model` (e.g. vLLM model name). Set them in the single Bruno env `lls` or as env vars for CLI/notebooks.

### 4.1 Bruno

- **Env:** One environment `lls.bru`: variables `base_url`, `model` (and `api_key` if required). User edits the env or sets env vars before run.
- **GUI:** Open collection (e.g. `bruno/openresponses-acceptance`), select env `lls`, run requests.
- **CLI:** `bruno run bruno/openresponses-acceptance -e lls` (ensure `BASE_URL` and `model` are set in env or in `lls.bru`).
- **Script:** `local/scripts/run-bruno-local.sh` checks `BASE_URL` is reachable, then runs Bruno with exit code; expects LLS already running.

### 4.2 Notebooks

- **`notebooks/README.md`:** Python 3.12+, venv, `pip install -r requirements.txt`. Set `BASE_URL` and model (env or in notebook). Run notebooks in `notebooks/` (as pytest tests or interactively).

### 4.3 Optional: running LLS locally (Podman / Compose)

- **`local/podman/README.md`:** For users who want to bring up LLS themselves: Postgres + LlamaStack scripts (or `docker-compose.yml`). After LLS is up, use `base_url` (e.g. `http://localhost:8321`) and model in Bruno/notebooks as above.

---

## 5. CI (optional)

**Assumption:** LLS is already running (e.g. started by workflow or a shared deployment). CI provides `BASE_URL` and `model` via env or GitHub secrets; same **single env** as local (`lls`).

- **Workflow** (e.g. `.github/workflows/functional-tests.yml`): Set `BASE_URL` and `model` (from env or secrets), then run e.g. `bruno run bruno/openresponses-acceptance -e lls`. Fail the job if Bruno exits non-zero.
- **Script:** `ci/scripts/run-bruno-ci.sh` runs Bruno; expects `BASE_URL` and `model` in environment.
- **Optional:** Start LLS in the same workflow (Podman/Docker) and set `BASE_URL` to the service URL; still use one env `lls` with that URL and model.

---

## 6. Implementation Order

1. **Create repo** (`llamastack-functional-tests`) and root `README.md` (overview: user provides URL + model; LLS assumed running; version-specific state on git branches).
2. **Add `bruno/environments/lls.bru`** – Single env with `base_url`, `model` (e.g. vllm), `api_key`. Document in `bruno/README.md`.
3. **Add `bruno/`** – Copy and normalize collections (openresponses-acceptance, chat-completions, embeddings, postgres-agents, upgrade, files) directly under `bruno/`.
4. **Add `local/scripts/run-bruno-local.sh`** – Health check + `bruno run bruno/... -e lls`; expects `BASE_URL` and `model` in env.
5. **Add `notebooks/`** – Copy chosen notebooks + MCP; `notebooks/README.md` (set BASE_URL + model).
6. **Add `docs/test-matrix.md`** – Feature → collection / notebook map.
7. **Optional CI** – `.github/workflows/functional-tests.yml` (set BASE_URL + model from env/secrets; run Bruno with `-e lls`); `ci/scripts/run-bruno-ci.sh`.
8. **Optional:** `local/podman/` scripts, `local/docker-compose.yml`; `bruno/scripts/generate-from-openapi.sh` and `docs/openapi-driven-tests.md`. **Containerfile** for CI: build image and run with same env vars elsewhere.

---

## 7. Naming and Conventions

- **Repo name:** `llamastack-functional-tests`.
- **Environment:** One only: **`lls`** (`bruno/environments/lls.bru`). Variables: `base_url`, `model` (vllm model name), `api_key` (if needed). User or CI provides these.
- **Version isolation:** Use **git branches** (e.g. `main`, `lls-5.x`, `lls-6.x`) to isolate version-specific test state; no version folders in the tree. Tests live under `bruno/`, `notebooks/`.
- **Bruno:** Use existing `script:post-response` assertions; collection folder names e.g. `openresponses-acceptance`, `chat-completions`.

---

## 7.1 Providers matrix (files, inference, vector_io)

Tests can be run against **provider combinations** aligned with [llama-stack-distribution/distribution](https://github.com/opendatahub-io/llama-stack-distribution/tree/main/distribution):

- **files:** e.g. `inline::localfs`, `remote::s3`
- **inference:** e.g. `remote::vllm`, `remote::azure`, `remote::bedrock` — each takes **model name** as input (user/CI provides `MODEL`)
- **vector_io:** e.g. `inline::milvus`, `remote::pgvector`, `remote::qdrant`

**Run:** Set `BASE_URL`, `MODEL`, and optionally `FILES_PROVIDER`, `INFERENCE_PROVIDER`, `VECTOR_IO_PROVIDER`, then:

```bash
./local/scripts/run-tests-with-providers.sh
# or run the container image with the same env vars (see Containerfile)
```

**Phases:** (1) Bruno **files** collection (isolated Files API endpoints), (2) Bruno **full** (all collections), (3) **Notebooks** (full-flow integration). See `docs/providers-matrix.md` and `config/providers-matrix.yaml`.

---

## 8. Optional Enhancements

- **Docker Compose** in `local/` (see layout): postgres + llama-stack for one-command local stack; document in `local/README.md`.
- **Containerfile**: build an image and run tests in CI with the same env vars (`BASE_URL`, `MODEL`, provider vars).
- **Test matrix:** `docs/test-matrix.md` (and/or a table in README) mapping each feature/capability to the Bruno collection(s) and notebook(s) that cover it—so “where do I test X?” is one lookup.
- **OpenResponses badge** in README if you align a collection to their compliance suite and they provide one.

---

## 9. API docs as source of truth & autogenerating tests

Use the **existing API documentation** (OpenAPI from LLS) so Bruno (or other) tests stay aligned with the **LLS version** you run against. Adjust or regenerate tests when the spec changes.

**LLS API docs (FastAPI, OAS 3.1):**

| Purpose | URL (with `BASE_URL` e.g. `http://localhost:8321`) |
|--------|----------------------------------------------------|
| Docs UI (Swagger) | `{BASE_URL}/docs` |
| OpenAPI spec (for import) | `{BASE_URL}/openapi.json` |

### 9.1 Where the spec comes from

- **LLS (FastAPI) serves OpenAPI at runtime:**
  - **Docs UI:** `{BASE_URL}/docs` (e.g. `http://localhost:8321/docs`) — FastAPI Swagger UI.
  - **OpenAPI spec (OAS 3.1):** `{BASE_URL}/openapi.json` — use this URL for Bruno import and for `generate-from-openapi.sh`. Tests then always match the running LLS version.
- **Fallback:** Static OpenAPI specs from the LlamaStack repo (e.g. [meta-llama/llama-stack](https://github.com/meta-llama/llama-stack) `docs/static/llama-stack-spec.yaml`). Pin by LLS version when the running instance is not available.

### 9.2 Autogenerating API tests from the spec

| Approach | How | Pros | Cons |
|---------|-----|------|------|
| **Bruno import (URL)** | In Bruno GUI: Import → OpenAPI → URL → `{{base_url}}/openapi.json`. Or CLI: `bru import openapi --source "${BASE_URL}/openapi.json" --output bruno/generated --collection-name "LLS API"`. | No code; collection stays in sync with spec. | LLS must be running; Bruno supports OpenAPI 3.x (OAS 3.1 is fine). |
| **Bruno import (file)** | Script: `curl -s "${BASE_URL}/openapi.json" -o spec.json`, then `bru import openapi --source spec.json --output bruno/generated`. Or use a versioned static spec from the repo. | Works offline once spec is saved; can pin spec per LLS version. | Need to obtain spec (fetch or versioned file). |
| **Bruno converter (Node)** | Use `@usebruno/converters`: `openApiToBruno(openApiSpec)` in a small script; write output to `bruno/generated/`. | Fully scriptable; same format as Bruno GUI import. | Requires Node; maintain a small script. |
| **Pytest + OpenAPI** | Generate pytest tests from the spec (e.g. schemathesis, or custom with `openapi-core`/requests). Run in CI alongside or instead of Bruno. | Single language; no Bruno dependency; good for contract/smoke tests. | Different toolchain; not Bruno collections. |

**Recommendation:** Use the **live spec** at `{BASE_URL}/openapi.json` when the stack is up. Add `bruno/scripts/generate-from-openapi.sh` that:

1. Sets `SPEC_URL="${BASE_URL}/openapi.json"`.
2. Fetches the spec; optionally rewrites `servers[].url` to `BASE_URL` if needed.
3. Runs `bru import openapi --source <spec> --output bruno/generated --collection-name "LLS API"`.
4. Optionally runs `bruno run bruno/generated -e lls` for a quick smoke.

Keep **hand-maintained** collections (openresponses-acceptance, postgres-agents, etc.) under `bruno/` for deeper assertions; use **generated** for broad endpoint coverage.

### 9.3 Docs to add

- **`docs/openapi-driven-tests.md`:** LLS docs at `{BASE_URL}/docs`, spec at `{BASE_URL}/openapi.json`; how to import into Bruno; how to run `generate-from-openapi.sh`.
- **`bruno/README.md`:** User provides base_url + model (env `lls`); link to OpenAPI-driven guide.

---

This plan gives you a single place for functional tests, **one env** (user provides URL + model), **git branches** for version-specific state, and optional CI that uses the same env.
