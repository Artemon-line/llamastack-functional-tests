# Functional test runner image: run Bruno + notebooks with the same env vars as local.
# Build: podman build -t llamastack-functional-tests .
# Run: pass BASE_URL, MODEL (required) and optional FILES_PROVIDER, INFERENCE_PROVIDER, VECTOR_IO_PROVIDER
#   podman run --rm -e BASE_URL=http://lls:8321 -e MODEL=my-model llamastack-functional-tests

FROM python:3.12-slim

# uv for fast Python installs
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Node for Bruno CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Python deps: jupyter + test/notebook deps (uv is faster than pip)
COPY requirements-test.txt .
RUN uv pip install --system --no-cache jupyter -r requirements-test.txt

RUN npm install -g @usebruno/cli

WORKDIR /workspace

COPY bruno/ bruno/
COPY config/ config/
COPY scripts/ scripts/
COPY notebooks/ notebooks/
COPY tests/ tests/
COPY docs/ docs/

# Same env vars as scripts/run-tests-with-providers.sh; override at run time (e.g. in CI).
ENV BASE_URL=""
ENV MODEL=""
ENV FILES_PROVIDER=""
ENV INFERENCE_PROVIDER=""
ENV VECTOR_IO_PROVIDER=""

RUN chmod +x /workspace/scripts/run-tests-with-providers.sh

ENTRYPOINT ["/bin/bash", "/workspace/scripts/run-tests-with-providers.sh"]
