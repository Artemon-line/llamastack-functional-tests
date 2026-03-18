# CLAUDE.md — Claude Code Instructions

See [AGENTS.md](AGENTS.md) for full project context, test strategy, and Bruno conventions.

## Quick Reference

- **Auto-generated tests:** `bruno/lls-api/` — do NOT edit, regenerate with `./bruno/scripts/generate-from-openapi.sh`
- **Hand-written CRUD tests:** `bruno/lls-crud/` — this is where you add tests
- **URL variable:** `{{baseUrl}}` (camelCase)
- **Model variable:** `{{model}}`
- **Run tests:** `cd bruno/lls-crud && npx --prefix .. bru run . -r --env-var baseUrl=http://localhost:8321 --env-var model=vllm-inference/llama-3-2-3b`

## Workflow for Adding CRUD Tests

1. Read the generated `.bru` file in `lls-api/` to understand the endpoint (URL, method, body schema)
2. Create the CRUD test in `lls-crud/NN-group/Action Resource.bru` following the templates in AGENTS.md
3. Run the test against the local server to verify it passes
4. Branch per LLS version (e.g., `0.6.0.1+rhai0`)
