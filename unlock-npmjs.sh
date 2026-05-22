#!/bin/bash
# Usage: ./unlock-npmjs.sh
# Allows verdaccio to reach npmjs.org for package installation.
set -eu
echo "Unlocking npmjs.org..."
sbx policy allow network "registry.npmjs.org:443"
echo "UNLOCKED. Run pnpm add to install packages."
echo "When done, run: ./lock-npmjs.sh"
