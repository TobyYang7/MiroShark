#!/bin/bash
# Start the Alva openai-api-wrapper server.
#
# Loads MiroShark/.env (sibling to this script) so ALVA_API_KEY and any
# other env vars are available, then execs the wrapper's server.js.
#
# The wrapper lives in a sibling worktree by default; override
# OPENAI_API_WRAPPER_DIR to point at a different checkout on another
# machine (e.g. /home/forge/mono-meta/local/alva-demos/openai-api).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="${SCRIPT_DIR}/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

DEFAULT_WRAPPER_DIR="${SCRIPT_DIR}/../worktrees/openai-wrapper/openai-api"
WRAPPER_DIR="${OPENAI_API_WRAPPER_DIR:-$DEFAULT_WRAPPER_DIR}"

if [ ! -f "${WRAPPER_DIR}/server.js" ]; then
  echo "ERROR: server.js not found at ${WRAPPER_DIR}" >&2
  echo "Set OPENAI_API_WRAPPER_DIR to the openai-api directory." >&2
  exit 1
fi

if [ -z "${ALVA_API_KEY:-}" ]; then
  echo "ERROR: ALVA_API_KEY not set (expected in ${ENV_FILE} or shell env)." >&2
  exit 1
fi

exec node "${WRAPPER_DIR}/server.js"

# ─────────────────────────────────────────────
# PM2 — manage all services:
#
#   pm2 start /Users/yuzheyang/dev/MiroShark/worktrees/miroshark-main/alva_server.sh --name alva-wrapper
#   pm2 start "uv run python run.py" \
#       --name miroshark-backend \
#       --cwd worktrees/miroshark-main/backend \
#       --env NO_PROXY=localhost,127.0.0.1 --env no_proxy=localhost,127.0.0.1
#   pm2 start "npm run dev -- --host" \
#       --name miroshark-frontend \
#       --cwd worktrees/miroshark-main/frontend
#
#   pm2 list              # view status
#   pm2 logs              # view all logs (real-time)
#   pm2 logs alva-wrapper # view alva logs only
#   pm2 restart all       # restart all services
#   pm2 stop all          # stop all services
#
# ─────────────────────────────────────────────
# Test with curl (run in a separate terminal):
#
# 1. Check available models:
#    curl --noproxy '127.0.0.1' http://127.0.0.1:8787/v1/models
#
# 2. Send a chat prompt:
#    curl --noproxy '127.0.0.1' -X POST http://127.0.0.1:8787/v1/chat/completions \
#      -H "Content-Type: application/json" \
#      -d '{
#        "model": "alva-adk",
#        "messages": [{"role": "user", "content": "What time is it?"}],
#        "max_tokens": 200
#      }'
#
# 3. Test embeddings stub:
#    curl --noproxy '127.0.0.1' -X POST http://127.0.0.1:8787/v1/embeddings \
#      -H "Content-Type: application/json" \
#      -d '{
#        "model": "text-embedding-3-small",
#        "input": ["hello world"],
#        "dimensions": 768
#      }'
# ─────────────────────────────────────────────
