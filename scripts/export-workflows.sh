#!/bin/sh
# Export every n8n workflow as one JSON file into ./workflows (credentials are never included)
set -e
cd "$(dirname "$0")/.."
docker compose exec -T n8n rm -rf /tmp/workflows
docker compose exec -T n8n n8n export:workflow --backup --output=/tmp/workflows/
rm -rf workflows && docker compose cp n8n:/tmp/workflows ./workflows
ls -1 workflows
