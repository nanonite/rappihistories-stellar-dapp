#!/usr/bin/env bash
# Usage: ./unlock-and-inspect.sh <package-name>
#
# Mechanized approval workflow for adding npm packages through Verdaccio.
# 1. Restarts Verdaccio with the npmjs uplink enabled.
# 2. Displays package metadata through the local Verdaccio registry.
# 3. Runs the current workspace audit when pnpm is available.
# 4. Prompts for human approval.
# 5. If approved: installs package through Verdaccio and re-locks.
# 6. If rejected or interrupted: re-locks immediately.

set -euo pipefail

PACKAGE="${1:-}"
REGISTRY="${NPM_CONFIG_REGISTRY:-http://localhost:4873}"

if [ -z "$PACKAGE" ]; then
    echo "Usage: $0 <package-name>"
    echo "Example: $0 @elenajs/core"
    exit 1
fi

relock() {
    ./lock-npmjs.sh >/dev/null
}

trap relock EXIT

echo "============================================"
echo " Package Inspection: $PACKAGE"
echo " Registry: $REGISTRY"
echo "============================================"

echo ""
echo "[1/5] Unlocking Verdaccio npmjs uplink..."
./unlock-npmjs.sh

echo ""
echo "[2/5] Inspecting package through Verdaccio..."

echo "--- Maintainers ---"
npm view "$PACKAGE" maintainers --registry "$REGISTRY" 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- Latest version ---"
npm view "$PACKAGE" version --registry "$REGISTRY" 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- Description ---"
npm view "$PACKAGE" description --registry "$REGISTRY" 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- License ---"
npm view "$PACKAGE" license --registry "$REGISTRY" 2>/dev/null || echo "(could not fetch)"

echo ""
echo "[3/5] Running pnpm audit on current lockfile..."
pnpm audit --audit-level high || true

echo ""
echo "[4/5] Review the information above."
read -rp "Approve and install $PACKAGE? [y/N] " answer
if [[ "$answer" != "y" ]]; then
    echo ""
    echo "Rejected. Re-locking Verdaccio. No changes made."
    exit 1
fi

echo ""
echo "[5/5] Installing $PACKAGE via Verdaccio..."
pnpm add "$PACKAGE"

echo ""
echo "============================================"
echo " Done. $PACKAGE installed and Verdaccio is being re-locked."
echo " Package is cached in Verdaccio for future locked installs."
echo "============================================"
