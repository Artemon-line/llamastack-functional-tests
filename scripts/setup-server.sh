#!/usr/bin/env bash
#
# Start PostgreSQL + LlamaStack containers, auto-discover the model, run tests.
#
# Usage:
#   ./scripts/setup-server.sh              # Full: start infra, run tests, cleanup
#   ./scripts/setup-server.sh --start-only # Start infra, discover model, print info
#   ./scripts/setup-server.sh --tests-only # Run tests against already-running server
#   ./scripts/setup-server.sh --cleanup    # Stop and remove containers
#
# Options:
#   --start-only     Start PostgreSQL + LlamaStack, then exit
#   --tests-only     Run tests against existing LLS (uses BASE_URL or localhost:8321)
#   --cleanup        Remove containers and exit
#   --no-cleanup     In full mode, keep containers after tests
#   --help           Show this help
#
# Infrastructure env vars (with defaults):
#   LLAMA_STACK_IMAGE   Container image (default: quay.io/rhoai/odh-llama-stack-core-rhel9:rhoai-3.4-linux-x86-64)
#   LLAMA_STACK_PORT    Host port for LLS (default: 8321)
#   POSTGRES_IMAGE      Postgres image (default: postgres:17-alpine)
#   POSTGRES_USER       Postgres user (default: llamastack)
#   POSTGRES_PASSWORD   Postgres password (default: llamastack)
#   POSTGRES_DB         Postgres database (default: postgres)
#   POSTGRES_PORT       Host port for Postgres (default: 5432)
#   CLEANUP_DB          Clean DB on startup: true/false (default: false)
#   MODEL               Inference model (default: auto-discovered from server)
#
# Provider env vars (forwarded to LLS container if set):
#   VLLM_URL, VLLM_API_TOKEN, VLLM_TLS_VERIFY
#   VLLM_EMBEDDING_URL, VLLM_EMBEDDING_API_TOKEN, VLLM_EMBEDDING_TLS_VERIFY
#   INFERENCE_MODEL, EMBEDDING_MODEL, EMBEDDING_PROVIDER, EMBEDDING_PROVIDER_MODEL_ID
#   GOOGLE_CLOUD_PROJECT, VERTEX_AI_PROJECT, VERTEX_AI_LOCATION, GOOGLE_APPLICATION_CREDENTIALS
#   AWS_BEARER_TOKEN_BEDROCK, AWS_DEFAULT_REGION
#   ENABLE_KUBEFLOW_GARAK, ENABLE_SENTENCE_TRANSFORMERS, LLAMA_STACK_LOGGING
#

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

LLAMA_STACK_IMAGE="${LLAMA_STACK_IMAGE:-quay.io/rhoai/odh-llama-stack-core-rhel9:rhoai-3.4-linux-x86-64}"
LLAMA_STACK_PORT="${LLAMA_STACK_PORT:-8321}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:17-alpine}"
POSTGRES_USER="${POSTGRES_USER:-llamastack}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-llamastack}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
CLEANUP_DB="${CLEANUP_DB:-false}"

CONTAINER_NAME_PG="postgres-local"
CONTAINER_NAME_LLS="llama-stack-local"
NETWORK_NAME="llama-stack-network"
VOLUME_NAME="postgres-data"

# Provider env vars forwarded to the LLS container (if set in calling env)
FORWARD_VARS=(
    INFERENCE_MODEL EMBEDDING_MODEL EMBEDDING_PROVIDER EMBEDDING_PROVIDER_MODEL_ID
    VLLM_TLS_VERIFY VLLM_EMBEDDING_TLS_VERIFY
    GOOGLE_CLOUD_PROJECT VERTEX_AI_PROJECT VERTEX_AI_LOCATION GOOGLE_APPLICATION_CREDENTIALS
    AWS_BEARER_TOKEN_BEDROCK AWS_DEFAULT_REGION
    ENABLE_KUBEFLOW_GARAK ENABLE_SENTENCE_TRANSFORMERS
    LLAMA_STACK_LOGGING
)

# Sensitive vars to mask in printed commands
SENSITIVE_KEYS_REGEX='^(POSTGRES_PASSWORD|AWS_BEARER_TOKEN_BEDROCK|VLLM_API_TOKEN|VLLM_EMBEDDING_API_TOKEN)$'

# ── Colors ────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Parse args ────────────────────────────────────────────────────────────────

MODE="full"
DO_CLEANUP=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-only)  MODE="start-only"; shift ;;
        --tests-only)  MODE="tests-only"; shift ;;
        --cleanup)     MODE="cleanup"; shift ;;
        --no-cleanup)  DO_CLEANUP=false; shift ;;
        --help|-h)
            sed -n '2,/^$/{ s/^# \?//; p }' "$0"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
done

# ── Preflight checks ─────────────────────────────────────────────────────────

check_prerequisites() {
    local missing=()
    command -v podman &>/dev/null || missing+=("podman")
    command -v curl &>/dev/null   || missing+=("curl")
    command -v python3 &>/dev/null || missing+=("python3")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}" >&2
        exit 1
    fi
}

# ── Functions ─────────────────────────────────────────────────────────────────

ensure_network() {
    if ! podman network exists "${NETWORK_NAME}" 2>/dev/null; then
        echo "Creating podman network: ${NETWORK_NAME}"
        podman network create "${NETWORK_NAME}"
    fi
}

start_postgres() {
    echo -e "${GREEN}Starting PostgreSQL...${NC}"

    # Force-remove existing container (non-interactive)
    podman rm -f "${CONTAINER_NAME_PG}" 2>/dev/null || true

    # Create volume if missing
    if ! podman volume exists "${VOLUME_NAME}" 2>/dev/null; then
        podman volume create "${VOLUME_NAME}"
    fi

    ensure_network

    podman run -d \
        --name "${CONTAINER_NAME_PG}" \
        --network "${NETWORK_NAME}" \
        -e "POSTGRES_DB=${POSTGRES_DB}" \
        -e "POSTGRES_USER=${POSTGRES_USER}" \
        -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" \
        -e "PGDATA=/var/lib/postgresql/data/pgdata" \
        -p "${POSTGRES_PORT}:5432" \
        -v "${VOLUME_NAME}:/var/lib/postgresql/data/pgdata" \
        "${POSTGRES_IMAGE}"

    # Wait for readiness
    echo "Waiting for PostgreSQL..."
    for i in {1..30}; do
        if podman exec "${CONTAINER_NAME_PG}" pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; then
            echo -e "${GREEN}PostgreSQL is ready.${NC}"

            # Optional DB cleanup
            if [[ "${CLEANUP_DB}" == "true" ]]; then
                echo "Cleaning up database..."
                if [[ "${POSTGRES_DB}" == "postgres" ]]; then
                    podman exec "${CONTAINER_NAME_PG}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
                        -c "DROP SCHEMA IF EXISTS public CASCADE;" 2>/dev/null || true
                    podman exec "${CONTAINER_NAME_PG}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
                        -c "CREATE SCHEMA public;" 2>/dev/null || true
                    podman exec "${CONTAINER_NAME_PG}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
                        -c "GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};" 2>/dev/null || true
                else
                    podman exec "${CONTAINER_NAME_PG}" psql -U "${POSTGRES_USER}" -d postgres \
                        -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};" 2>/dev/null || true
                    podman exec "${CONTAINER_NAME_PG}" psql -U "${POSTGRES_USER}" -d postgres \
                        -c "CREATE DATABASE ${POSTGRES_DB};"
                fi
                echo -e "${GREEN}Database cleaned up.${NC}"
            fi
            return 0
        fi
        if [[ $i -eq 30 ]]; then
            echo -e "${RED}PostgreSQL did not become ready within 30 seconds.${NC}" >&2
            podman logs "${CONTAINER_NAME_PG}" 2>&1 | tail -20
            exit 1
        fi
        sleep 1
    done
}

start_llama_stack() {
    # Verify postgres is running
    if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME_PG}$"; then
        echo -e "${RED}PostgreSQL container '${CONTAINER_NAME_PG}' is not running.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Starting LlamaStack...${NC}"
    echo "Image: ${LLAMA_STACK_IMAGE}"

    # Force-remove existing
    podman rm -f "${CONTAINER_NAME_LLS}" 2>/dev/null || true

    ensure_network

    # Build podman run arguments
    local RUN_ARGS=(
        --name "${CONTAINER_NAME_LLS}"
        --network "${NETWORK_NAME}"
        -p "${LLAMA_STACK_PORT}:8321"
        -e "POSTGRES_HOST=${CONTAINER_NAME_PG}"
        -e "POSTGRES_PORT=5432"
        -e "POSTGRES_DB=${POSTGRES_DB}"
        -e "POSTGRES_USER=${POSTGRES_USER}"
        -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
    )

    # Forward VLLM_URL with /v1 suffix if needed
    if [[ -n "${VLLM_URL:-}" ]]; then
        local vllm_url="${VLLM_URL}"
        [[ "${vllm_url}" != */v1 ]] && vllm_url="${vllm_url}/v1"
        RUN_ARGS+=(-e "VLLM_URL=${vllm_url}")
    fi
    if [[ -n "${VLLM_API_TOKEN:-}" ]]; then
        RUN_ARGS+=(-e "VLLM_API_TOKEN=${VLLM_API_TOKEN}")
    fi

    # Forward VLLM_EMBEDDING_URL with /v1 suffix if needed
    if [[ -n "${VLLM_EMBEDDING_URL:-}" ]]; then
        local embed_url="${VLLM_EMBEDDING_URL}"
        [[ "${embed_url}" != */v1 ]] && embed_url="${embed_url}/v1"
        RUN_ARGS+=(-e "VLLM_EMBEDDING_URL=${embed_url}")
    fi
    if [[ -n "${VLLM_EMBEDDING_API_TOKEN:-}" ]]; then
        RUN_ARGS+=(-e "VLLM_EMBEDDING_API_TOKEN=${VLLM_EMBEDDING_API_TOKEN}")
    fi

    # Forward remaining provider vars if set
    for var in "${FORWARD_VARS[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            RUN_ARGS+=(-e "${var}=${!var}")
        fi
    done

    # Print sanitized command
    echo -e "${BLUE}podman run -d${NC}"
    for arg in "${RUN_ARGS[@]}"; do
        if [[ "$arg" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
            local env_key="${BASH_REMATCH[1]}"
            if [[ "$env_key" =~ $SENSITIVE_KEYS_REGEX ]]; then
                echo -e "  ${BLUE}${env_key}=********${NC}"
                continue
            fi
        fi
        echo -e "  ${BLUE}${arg}${NC}"
    done
    echo -e "  ${BLUE}${LLAMA_STACK_IMAGE}${NC}"

    podman run -d "${RUN_ARGS[@]}" "${LLAMA_STACK_IMAGE}"

    sleep 3
    wait_for_health
}

wait_for_health() {
    local health_url="http://localhost:${LLAMA_STACK_PORT}/v1/health"
    local max_attempts=60

    echo -e "${BLUE}Waiting for LlamaStack health check...${NC}"

    for i in $(seq 1 $max_attempts); do
        local response http_code body
        response=$(curl -s -w "\n%{http_code}" "${health_url}" 2>/dev/null || echo -e "\n000")
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | head -n-1)

        if [[ "$http_code" == "200" ]]; then
            if echo "$body" | grep -q '"status".*"OK"'; then
                echo -e "${GREEN}LlamaStack is healthy!${NC}"
                return 0
            fi
        fi

        if (( i % 5 == 0 )); then
            echo -e "${YELLOW}  Attempt ${i}/${max_attempts}... (HTTP ${http_code})${NC}"
        fi
        sleep 2
    done

    echo -e "${RED}Health check failed after ${max_attempts} attempts.${NC}" >&2
    echo "Check logs: podman logs ${CONTAINER_NAME_LLS}" >&2
    podman logs "${CONTAINER_NAME_LLS}" 2>&1 | tail -30
    exit 1
}

discover_model() {
    if [[ -n "${MODEL:-}" ]]; then
        echo "Using pre-set MODEL=${MODEL}"
        return 0
    fi

    local models_url="http://localhost:${LLAMA_STACK_PORT}/v1/models"
    echo "Discovering inference model from ${models_url}..."

    local response
    response=$(curl -sS "${models_url}") || {
        echo -e "${RED}Failed to query /v1/models${NC}" >&2
        exit 1
    }

    MODEL=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
for m in data.get('data', []):
    meta = m.get('custom_metadata', {}) or {}
    if meta.get('model_type') != 'embedding':
        print(m['id']); sys.exit(0)
print('')
" <<< "$response")

    if [[ -z "$MODEL" ]]; then
        echo -e "${RED}No non-embedding model found on the server.${NC}" >&2
        echo "Response:" >&2
        python3 -m json.tool <<< "$response" 2>/dev/null || echo "$response" >&2
        exit 1
    fi

    export MODEL
    echo -e "${GREEN}Discovered model: ${MODEL}${NC}"
}

run_tests() {
    export BASE_URL="http://localhost:${LLAMA_STACK_PORT}"
    export MODEL

    echo -e "${GREEN}Running functional tests...${NC}"
    echo "  BASE_URL=${BASE_URL}"
    echo "  MODEL=${MODEL}"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "${script_dir}/run-tests-with-providers.sh"
}

cleanup() {
    echo -e "${YELLOW}Cleaning up containers...${NC}"
    for c in "${CONTAINER_NAME_LLS}" "${CONTAINER_NAME_PG}"; do
        podman rm -f "$c" 2>/dev/null || true
    done
    echo -e "${GREEN}Containers removed.${NC}"
    echo "Network '${NETWORK_NAME}' and volume '${VOLUME_NAME}' kept for fast restarts."
    echo "To remove: podman network rm ${NETWORK_NAME}; podman volume rm ${VOLUME_NAME}"
}

print_status() {
    echo ""
    echo "================================"
    echo -e "${GREEN}Infrastructure is running.${NC}"
    echo "================================"
    echo "  LLS server:  http://localhost:${LLAMA_STACK_PORT}"
    echo "  PostgreSQL:  localhost:${POSTGRES_PORT}"
    echo "  MODEL:       ${MODEL}"
    echo "  Image:       ${LLAMA_STACK_IMAGE}"
    echo ""
    echo "Run tests:"
    echo "  ./scripts/setup-server.sh --tests-only"
    echo "  # or manually:"
    echo "  BASE_URL=http://localhost:${LLAMA_STACK_PORT} MODEL=${MODEL} ./scripts/run-tests-with-providers.sh"
    echo ""
    echo "Logs:"
    echo "  podman logs -f ${CONTAINER_NAME_LLS}"
    echo ""
    echo "Cleanup:"
    echo "  ./scripts/setup-server.sh --cleanup"
}

# ── Main ──────────────────────────────────────────────────────────────────────

check_prerequisites

case "$MODE" in
    cleanup)
        cleanup
        ;;

    tests-only)
        export BASE_URL="${BASE_URL:-http://localhost:${LLAMA_STACK_PORT}}"
        # Verify server is reachable
        if ! curl -fsS "${BASE_URL}/v1/health" >/dev/null 2>&1; then
            echo -e "${RED}No LLS server at ${BASE_URL}${NC}" >&2
            echo "Start one first, or run without --tests-only for full setup." >&2
            exit 1
        fi
        echo -e "${GREEN}Found running LLS at ${BASE_URL}${NC}"
        discover_model
        run_tests
        ;;

    start-only)
        start_postgres
        start_llama_stack
        discover_model
        print_status
        ;;

    full)
        if [[ "$DO_CLEANUP" == true ]]; then
            trap cleanup EXIT
        fi
        start_postgres
        start_llama_stack
        discover_model
        run_tests
        echo -e "${GREEN}All tests passed!${NC}"
        ;;
esac
