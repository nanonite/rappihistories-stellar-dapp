#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
COMPOSE=(docker compose -f "$REPO_ROOT/e2e/docker-compose.yml")

export VERDACCIO_CONFIG="${VERDACCIO_CONFIG:-$REPO_ROOT/components/web/verdaccio-config.yaml}"
export MANUAL_E2E_ENABLED="${MANUAL_E2E_ENABLED:-1}"

cd "$REPO_ROOT"

"$SCRIPT_DIR/bootstrap-verdaccio-cache.sh"

if [[ "${MANUAL_E2E_PRESERVE_STATE:-0}" != "1" ]]; then
  "${COMPOSE[@]}" --profile test down -v --remove-orphans
fi

"${COMPOSE[@]}" up -d verdaccio
"${COMPOSE[@]}" build
"${COMPOSE[@]}" --profile test up -d \
  stellar-local \
  postgres \
  minio \
  contract-runner \
  api-indexer \
  kms-gate \
  tier3-contract-flow \
  breakglass-contract-flow \
  prescription-contract-flow \
  kms-conformance-contract-flow \
  web

echo
echo "Manual local MVP e2e demo is starting."
echo "Open: http://127.0.0.1:${WEB_PORT:-3001}/manual-e2e"
echo
echo "Health checks:"
echo "  api-indexer: http://127.0.0.1:${API_INDEXER_PORT:-8788}/v1/health"
echo "  kms-gate:    http://127.0.0.1:${KMS_GATE_PORT:-8790}/v1/health"
echo "  web:         http://127.0.0.1:${WEB_PORT:-3001}"
echo
echo "If the page initially shows pending scenario files, wait a few seconds and press Refresh."
