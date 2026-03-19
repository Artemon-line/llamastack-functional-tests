# CLAUDE.md — Claude Code Instructions

See [AGENTS.md](AGENTS.md) for full project context, test strategy, and Bruno conventions.

## Quick Reference

- **Auto-generated tests:** `bruno/lls-api/` — do NOT edit, regenerate with `./bruno/scripts/generate-from-openapi.sh`
- **Hand-written CRUD tests:** `bruno/lls-crud/` — this is where you add tests
- **Notebooks:** `notebooks/` — executable demos that double as tests
- **URL variable:** `{{baseUrl}}` (camelCase) in Bruno; `BASE_URL` env in notebooks
- **Model variable:** `{{model}}` in Bruno; `MODEL` env in notebooks
- **NEVER hardcode model names** — always pass via variable/env. No defaults for MODEL.
- **Client/server version match:** Before running notebooks, verify `llama-stack-client` version in `pyproject.toml` matches the server (e.g., server `0.3.5.1` → client `==0.3.5`). Use `uv sync` to install, `uv run` to execute.
- **Notebook deps:** `ipykernel` must be in `pyproject.toml` dependencies. Run `uv sync` before executing notebooks.

## Workflow for Adding CRUD Tests

1. Read the generated `.bru` file in `lls-api/` to understand the endpoint (URL, method, body schema)
2. Create the CRUD test in `lls-crud/NN-group/Action Resource.bru` following the templates in AGENTS.md
3. Run the test against the local server to verify it passes
4. Branch per LLS version (e.g., `0.6.0.1+rhai0`)

## Workflow for Adding Notebooks

1. Create notebook in `notebooks/` with markdown intro + code cells with assertions
2. Read MODEL from `os.environ.get("MODEL")` — no default, fail fast with clear error
3. Assert on structure (types, fields), never on content (LLM output varies)
4. Verify notebook runs: `BASE_URL=... MODEL=... uv run pytest tests/test_notebooks.py -k notebook_name -v`
