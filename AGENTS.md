# AGENTS.md — AI Agent Instructions for OGX Functional Tests

This file provides instructions for any AI coding agent (Claude Code, Cursor, Copilot, etc.) working on this repo.

## Project Purpose

Functional tests for **OGX** using [Bruno](https://www.usebruno.com/) API collections. The server is assumed **running** — tests validate endpoints, not deployment.

## Repository Layout

> **Note:** The layout below reflects the **current branch**. Each OGX version is tracked on its own branch (e.g., `0.6.0.1+rhai0`, `0.2.22.2+rhai0`). Collections, endpoints, and folder structure may differ between branches — always check what exists on the branch you are working on. Do NOT assume folders or files from another branch are present.

```text
bruno/
  ogx-api/            ← AUTO-GENERATED from OpenAPI (do NOT edit by hand)
    <ApiGroup>/        ← subfolder per API group (varies by OGX version)
    collection.bru     ← collection config (baseUrl variable defined here)
    bruno.json
  ogx-crud/            ← HAND-WRITTEN CRUD tests with assertions (create this)
    NN-group/          ← numbered folders, contents vary by branch
    collection.bru
  environments/
    ogx.bru            ← shared env vars: baseUrl, model, provider labels
  scripts/
    generate-from-openapi.sh  ← regenerate ogx-api from running server
  package.json         ← npm scripts: bruno:generate, bruno:run
scripts/
  run-tests-with-providers.sh ← main test runner (Bruno + notebooks)
```

### Branching Strategy

- **One branch per OGX version** (e.g., `0.6.0.1+rhai0` for OGX 0.6.x, `0.2.22.2+rhai0` for OGX 0.2.x)
- The OpenAPI spec and available endpoints change between OGX versions — always regenerate `ogx-api/` from the target server
- CRUD tests in `ogx-crud/` are version-specific; cherry-pick shared infrastructure (scripts, package.json, .gitignore) across branches as needed
- Before writing tests, run `./bruno/scripts/generate-from-openapi.sh` against the target server and inspect `ogx-api/` to see what endpoints exist on this version

## Two-Layer Test Strategy

### Layer 1: `ogx-api/` — Auto-generated (baseline)

- Generated from OpenAPI spec via `./bruno/scripts/generate-from-openapi.sh`
- Covers all endpoints with placeholder request bodies
- **Never edit these files** — they get overwritten on regeneration
- Purpose: smoke test that all endpoints are reachable

### Layer 2: `ogx-crud/` — Hand-written (your task)

- CRUD tests with **real request bodies**, **assertions**, and **variable chaining**
- Organized in numbered folders for execution order (Bruno runs alphabetically)
- This is where agents add value

## How to Write CRUD Tests

### Conventions

1. **Folder naming:** `NN-group/` (e.g., `01-admin/`, `02-models/`, `03-inference/`)
2. **File naming:** `Action Resource.bru` (e.g., `Create File.bru`, `List Models.bru`)
3. **Sequencing:** Use `seq` in meta to control order within a folder
4. **Variable chaining:** Use `bru.setEnvVar()` in post-response scripts to pass IDs between requests (e.g., create → get → delete)
5. **Base URL variable:** Use `{{baseUrl}}` (camelCase) to match the generated collection
6. **Model variable:** Use `{{model}}` for any inference request

### Bruno .bru File Template (GET)

```bru
meta {
  name: List Models
  type: http
  seq: 1
}

get {
  url: {{baseUrl}}/v1/models
  body: none
  auth: inherit
}

script:post-response {
  test("Status is 200", function() {
    expect(res.getStatus()).to.eql(200);
  });
  test("Response has data array", function() {
    const body = res.getBody();
    expect(body).to.have.property("data");
    expect(body.data).to.be.an("array");
  });
}
```

### Bruno .bru File Template (POST with variable chaining)

```bru
meta {
  name: Create Vector Store
  type: http
  seq: 1
}

post {
  url: {{baseUrl}}/v1/vector_stores
  body: json
  auth: inherit
}

body:json {
  {
    "name": "test-store"
  }
}

script:post-response {
  test("Status is 200 or 201", function() {
    expect([200, 201]).to.include(res.getStatus());
  });
  test("Store created and ID saved", function() {
    const body = res.getBody();
    expect(body.id).to.be.a("string");
    bru.setEnvVar("vector_store_id", body.id);
  });
}
```

### Bruno .bru File Template (DELETE using chained variable)

```bru
meta {
  name: Delete Vector Store
  type: http
  seq: 4
}

delete {
  url: {{baseUrl}}/v1/vector_stores/{{vector_store_id}}
  body: none
  auth: inherit
}

script:post-response {
  test("Status is 200 or 204", function() {
    expect([200, 204]).to.include(res.getStatus());
  });
}
```

### What to Assert

- **Status codes:** Always assert expected status (200, 201, 204, etc.)
- **Response shape:** Check key fields exist and have correct types
- **Variable chaining:** After create, save the ID; use it in get/update/delete
- **Don't assert:** Exact values that change between environments (timestamps, UUIDs)

## CRUD Groups to Implement

Analyze `ogx-api/` subfolders and the server's `/v1/providers` response to determine which groups are available. Typical groups:

| Priority | Group | Endpoints | Notes |
|----------|-------|-----------|-------|
| 1 | Admin | version, health, providers, routes | Always available, no setup needed |
| 2 | Models | list, get | Read-only, use `{{model}}` |
| 3 | Inference | chat completions | Requires valid `{{model}}` |
| 4 | Files | create, list, get, delete | Full CRUD, chain `file_id` |
| 5 | Vector Stores | create, list, get, delete | Full CRUD, chain `vector_store_id` |
| 6 | Responses | create, list, get | Uses `{{model}}` |
| 7 | Agents | create session, create turn | Complex, depends on inference |

## Running Tests

```bash
# Run all generated tests
cd bruno && npm run bruno:run -- --env-var baseUrl=http://localhost:8321 --env-var model=vllm-inference/llama-3-2-3b

# Run CRUD tests only
cd bruno/ogx-crud && npx --prefix .. bru run . -r --env-var baseUrl=http://localhost:8321 --env-var model=vllm-inference/llama-3-2-3b

# Full provider-matrix run
BASE_URL=http://localhost:8321 MODEL=vllm-inference/llama-3-2-3b ./scripts/run-tests-with-providers.sh
```

## Important Rules

- **Never hardcode model names or provider-specific values.** Models and embedding models must come from variables (`{{model}}`, `{{embedding_model}}` in Bruno; `MODEL` env var in notebooks). Defaults for `baseUrl` are OK (`http://localhost:8321`), but model names are environment-specific and must always be passed in. Same applies to embedding model names, provider IDs, and API keys.
- **Never edit files in `ogx-api/`** — they are auto-generated
- **Always read the generated `.bru` file** for an endpoint before writing its CRUD test — it shows the correct URL, method, and request body schema
- **Use `baseUrl`** (camelCase), not `base_url` — this matches the OpenAPI-generated collection
- **Test against a running server** before committing — run `bru run . -r` from the collection dir
- **Branch per OGX version** — e.g., `0.6.0.1+rhai0` for OGX 0.6.x, `0.2.22.2+rhai0` for OGX 0.2.x

## Notebook Conventions

Notebooks in `notebooks/` serve as **both executable tests and feature demos**. They are run as pytest tests via `nbformat` ExecutePreprocessor.

- **No hardcoded model names.** Read `MODEL` from `os.environ.get("MODEL")` with **no default**. Fail fast with a clear error if not set.
- `BASE_URL` may default to `http://localhost:8321`.
- Assert on **structure** (field names, types, array lengths > 0), never on **content** (LLM output is non-deterministic).
- Each notebook starts with a markdown cell explaining what it demonstrates.
- **Check existing notebooks before creating new ones.** Do not duplicate — modify or extend existing notebooks. Only create a new notebook for a genuinely new feature or scenario.
- See `notebooks/README.md` for the full pattern including `config.notebook_env` usage.
