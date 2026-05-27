#!/usr/bin/env bash
# Usage: ./lock-npmjs.sh
# Re-locks Verdaccio by restarting it without an npmjs uplink.
set -eu
echo "Switching Verdaccio to LOCKED mode..."
VERDACCIO_CONFIG=./verdaccio-config.yaml docker compose up -d --force-recreate verdaccio
echo "LOCKED. Verdaccio will serve cached packages only."
