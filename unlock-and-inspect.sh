#!/bin/bash
# Usage: ./unlock-and-inspect.sh <sandbox-name> <package-name>
#
# Mechanized lock/unlock workflow for adding npm packages through verdaccio.
# 1. Unlocks npmjs.org in sbx network policy
# 2. Displays maintainers, downloads, version, audit results
# 3. Prompts for human approval
# 4. If approved: installs package through verdaccio, re-locks npmjs
# 5. If rejected: re-locks immediately, no changes made

set -euo pipefail

SANDBOX="${1:-}"
PACKAGE="${2:-}"

if [ -z "$SANDBOX" ] || [ -z "$PACKAGE" ]; then
    echo "Usage: $0 <sandbox-name> <package-name>"
    echo "Example: $0 stellar-dapp @stellar/stellar-sdk"
    exit 1
fi

echo "============================================"
echo " Package Inspection: $PACKAGE"
echo " Sandbox: $SANDBOX"
echo "============================================"

# 1. UNLOCK — allow verdaccio to reach npmjs
echo ""
echo "[1/5] Unlocking npmjs.org access..."
sbx policy allow network "registry.npmjs.org:443"
sleep 2
echo "npmjs.org UNLOCKED."

# 2. INSPECT — gather security signals from npm registry
echo ""
echo "[2/5] Inspecting package..."

echo "--- Maintainers ---"
npm view "$PACKAGE" maintainers 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- Latest version ---"
npm view "$PACKAGE" version 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- Weekly downloads ---"
npm view "$PACKAGE" downloads 2>/dev/null || echo "(could not fetch)"

echo ""
echo "--- Description ---"
npm view "$PACKAGE" description 2>/dev/null || echo "(could not fetch)"

# 3. AUDIT — check current lockfile for known vulnerabilities
echo ""
echo "[3/5] Running pnpm audit on current lockfile..."
sbx exec "$SANDBOX" bash -c "cd /home/goya/stellar-dapp-workspace && pnpm audit --audit-level high 2>&1" || true

# 4. HUMAN DECISION
echo ""
echo "[4/5] Review the information above."
read -rp "Approve and install $PACKAGE? [y/N] " answer
if [[ "$answer" != "y" ]]; then
    echo ""
    echo "Rejected. Re-locking..."
    sbx policy rm network "registry.npmjs.org:443"
    echo "RE-LOCKED. No changes made."
    exit 1
fi

# 5. INSTALL + RE-LOCK
echo ""
echo "[5/5] Installing $PACKAGE via verdaccio..."
sbx exec "$SANDBOX" bash -c "cd /home/goya/stellar-dapp-workspace && pnpm add $PACKAGE"

echo ""
echo "Re-locking npmjs.org access..."
sbx policy rm network "registry.npmjs.org:443"

echo ""
echo "============================================"
echo " Done. $PACKAGE installed and npmjs RE-LOCKED."
echo " Package is cached in verdaccio for future offline use."
echo "============================================"
