#!/usr/bin/env bash
# Deterministic local e2e startup:
# 1. clone the approved development Verdaccio storage into the e2e volume
# 2. start the e2e Verdaccio container with the locked config
# 3. build images against the running e2e registry
# 4. start the full stack
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
export VERDACCIO_CONFIG="${VERDACCIO_CONFIG:-$REPO_ROOT/components/web/verdaccio-config.yaml}"
cd "$REPO_ROOT"
COMPOSE=(docker compose -f e2e/docker-compose.yml)

"$SCRIPT_DIR/bootstrap-verdaccio-cache.sh"
"${COMPOSE[@]}" up -d verdaccio
"${COMPOSE[@]}" build
"${COMPOSE[@]}" up
