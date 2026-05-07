# CLAUDE.md — Claude Code Instructions

See [AGENTS.md](AGENTS.md) for full project context, test strategy, and Bruno conventions.

## Quick Reference

- **Auto-generated tests:** `bruno/ogx-api/` — do NOT edit, regenerate with `./bruno/scripts/generate-from-openapi.sh`
- **Hand-written CRUD tests:** `bruno/ogx-crud/` — this is where you add tests
- **Notebooks:** `notebooks/` — executable demos that double as tests
- **URL variable:** `{{baseUrl}}` (camelCase) in Bruno; `BASE_URL` env in notebooks
- **Model variable:** `{{model}}` in Bruno; `MODEL` env in notebooks
- **NEVER hardcode model names** — always pass via variable/env. No defaults for MODEL.

## Workflow for Adding CRUD Tests

1. Read the generated `.bru` file in `ogx-api/` to understand the endpoint (URL, method, body schema)
2. Create the CRUD test in `ogx-crud/NN-group/Action Resource.bru` following the templates in AGENTS.md
3. Run the test against the local server to verify it passes
4. Branch per OGX version (e.g., `0.6.0.1+rhai0`)

## Workflow for Adding Notebooks

1. Create notebook in `notebooks/` with markdown intro + code cells with assertions
2. Read MODEL from `os.environ.get("MODEL")` — no default, fail fast with clear error
3. Assert on structure (types, fields), never on content (LLM output varies)
4. Verify notebook runs: `BASE_URL=... MODEL=... python3 -m pytest tests/test_notebooks.py -k notebook_name -v`
