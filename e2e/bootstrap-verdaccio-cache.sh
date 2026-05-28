#!/usr/bin/env bash
# Clone the approved development Verdaccio cache into the e2e Verdaccio volume.
#
# This keeps e2e package access locked while avoiding a networked npmjs seed
# step during normal test runs. Package approval and npmjs fetching still happen
# through the development Verdaccio workflow in components/web/{unlock,lock}-npmjs.sh.
set -euo pipefail

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DEV_VOLUME="${DEV_VERDACCIO_VOLUME:-stellar-dapp-workspace_verdaccio-storage}"
E2E_VOLUME="${E2E_VERDACCIO_VOLUME:-e2e_verdaccio-storage}"

docker volume inspect "$DEV_VOLUME" >/dev/null
docker volume create "$E2E_VOLUME" >/dev/null

docker run --rm \
  -v "$DEV_VOLUME":/from:ro \
  -v "$E2E_VOLUME":/to \
  docker.io/library/node:22-bookworm \
  sh -eu -c 'cd /from && tar cf - . | tar xf - -C /to'

echo "Seeded $E2E_VOLUME from $DEV_VOLUME"
echo "Next: e2e/up.sh"
