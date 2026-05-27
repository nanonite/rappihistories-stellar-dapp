#!/usr/bin/env bash
# Usage: ./unlock-npmjs.sh
# Restarts Verdaccio with an npmjs uplink for approved package installation.
set -eu
echo "Switching Verdaccio to UNLOCKED mode..."
VERDACCIO_CONFIG=./verdaccio-config.unlocked.yaml docker compose up -d --force-recreate verdaccio
echo "UNLOCKED. Run pnpm add to install approved packages through Verdaccio."
echo "When done, run: ./lock-npmjs.sh"
