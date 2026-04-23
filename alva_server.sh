#!/bin/bash
# Start Alva openai-api-wrapper
# Load the .env file from the project root directory
# Path: MiroShark/.env (relative to backend/app/config.py)
project_root_env = os.path.join(os.path.dirname(__file__), '../../.env')

if os.path.exists(project_root_env):
    load_dotenv(project_root_env, override=True)
else:
    # If no .env in root directory, try loading environment variables (for production)
    load_dotenv(override=True)
exec node /Users/yuzheyang/dev/MiroShark/worktrees/openai-wrapper/openai-api/server.js

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
