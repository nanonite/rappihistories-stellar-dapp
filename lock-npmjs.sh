#!/bin/bash
# Usage: ./lock-npmjs.sh
# Re-locks npmjs.org — packages must be cached in verdaccio.
set -eu
echo "Re-locking npmjs.org..."
sbx policy rm network "registry.npmjs.org:443" 2>/dev/null || echo "Policy already removed."
echo "LOCKED. Only verdaccio-cached packages available."
