# OGX Functional Testing Repository

Functional tests for **OGX** using Bruno API collections and Jupyter notebooks. The server is assumed **running** — tests validate endpoints, not deployment.

**Assumption:** User (or CI) provides `BASE_URL` and `MODEL` to test against. No environment-specific config in the repo.

## Repository Layout

```text
ogx-functional-tests/
├── bruno/
│   ├── ogx-api/              ← Auto-generated from OpenAPI (do NOT edit)
│   ├── ogx-crud/             ← Hand-written CRUD tests with assertions
│   │   ├── 01-admin/         ← version, health, providers, routes
│   │   ├── 02-models/        ← list, get
│   │   ├── 03-inference/     ← chat completions
│   │   ├── 04-files/         ← create, list, get, delete (full CRUD)
│   │   ├── 05-vector-stores/ ← create, list, get, delete (where available)
│   │   ├── 06-responses/     ← create, list, get
│   │   ├── collection.bru    ← baseUrl variable
│   │   └── bruno.json
│   ├── environments/
│   ├── scripts/
│   │   └── generate-from-openapi.sh
│   └── package.json
├── notebooks/
│   ├── test_responses.ipynb
│   ├── test_streaming_responses.ipynb
│   ├── test_basic_inference.ipynb
│   ├── test_openapi.ipynb
│   ├── test_rag.ipynb
│   ├── test_mcp_tooling.ipynb
│   └── test_negative.ipynb
├── scripts/
│   ├── run-tests-with-providers.sh  ← Main test runner
│   ├── sync-client-version.sh       ← Auto-sync client SDK to server
│   ├── bruno-summary.py             ← Bruno JSON → summary + JUnit XML
│   ├── setup-server.sh              ← Local server setup (Podman)
│   └── helpers.py                   ← Shared notebook helpers
├── tests/
│   └── test_notebooks.py            ← Pytest runner for notebooks
├── reports/                          ← JUnit XML output (gitignored)
│   ├── bruno-crud.xml
│   └── notebooks.xml
├── config/
│   ├── notebook_env.py
│   └── providers-matrix.yaml
├── docs/
│   └── providers-matrix.md
├── .pre-commit-config.yaml           ← ruff, shellcheck, markdownlint
├── pyproject.toml
├── Containerfile
└── AGENTS.md                         ← AI agent instructions
```

## Branching Strategy

- **One branch per OGX version** (e.g. `0.7.1+rhaiv.1`, `0.6.0.1+rhai0`, `0.2.22.2+rhai0`)
- `main` tracks the latest server version
- CI infrastructure (scripts, pre-commit, JUnit XML) is shared across all branches
- API-specific test content (`.bru` files, notebooks) varies per branch

### New version branch pattern

1. `git checkout -b X.Y.Z+rhai0 main`
2. Run `BASE_URL=... MODEL=... ./scripts/run-tests-with-providers.sh`
3. `sync-client-version.sh` auto-upgrades the client SDK to match the server
4. Fix any API path changes in `.bru` files
5. Commit and push

## Test Execution

### Two-phase runner

`scripts/run-tests-with-providers.sh` runs both phases:

**Phase 1 — Bruno CRUD tests** (`bruno/ogx-crud/`)

- Hand-written tests with assertions and variable chaining
- Output parsed by `bruno-summary.py` for accurate assertion counts
- JUnit XML: `reports/bruno-crud.xml`

**Phase 2 — Notebook tests** (`notebooks/`)

- Executed via pytest + `nbformat.ExecutePreprocessor`
- JUnit XML: `reports/notebooks.xml`

### Running

```bash
export BASE_URL="http://localhost:8321"
export MODEL="vllm-inference/llama-3-2-3b"
./scripts/run-tests-with-providers.sh
```

### Provider matrix

Iterate over providers by running the script multiple times:

```bash
for model in "vllm-inference/llama-3-2-3b" "vertexai/.../gemini-2.0-flash" "openai/gpt-4o-mini"; do
  MODEL="$model" BASE_URL=http://localhost:8321 VECTOR_IO_PROVIDER=pgvector \
    ./scripts/run-tests-with-providers.sh
done
```

## CI Integration

JUnit XML reports at `reports/bruno-crud.xml` and `reports/notebooks.xml` are consumed by any CI system (GitHub Actions, GitLab CI, Jenkins, ReportPortal).

The runner also:

- Auto-syncs `ogx-client` to match server version (no HTTP 426 mismatches)
- Recovers port-forwarding if the connection drops mid-run
- Filters Bruno CLI noise (proxy warnings, misleading 0/0 summary)

## Pre-commit

All branches have `.pre-commit-config.yaml` with:

- **ruff** — Python linting and formatting
- **shellcheck** — Shell script analysis
- **markdownlint** — Markdown consistency
- **trailing-whitespace / end-of-file-fixer** — Whitespace hygiene

Run: `uv run pre-commit run --all-files`

## Conventions

- `{{baseUrl}}` (camelCase) in Bruno; `BASE_URL` env in notebooks
- `{{model}}` in Bruno; `MODEL` env in notebooks — **never hardcoded**
- `script:post-response` (no space) for Bruno test blocks
- Notebooks assert on **structure** (types, fields), never on **content** (LLM output varies)
- See `AGENTS.md` for full AI agent instructions and `.bru` file templates
