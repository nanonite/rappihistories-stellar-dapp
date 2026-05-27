# Dependency Management

## Verdaccio Service

The project uses a repository-owned Verdaccio Docker container as the npm
registry/cache.

```bash
docker compose up -d verdaccio
```

The repo `.npmrc` points pnpm to:

```text
http://localhost:4873/
```

The container publishes only to `127.0.0.1:4873` on the Docker host and stores
cached packages in the named Docker volume `verdaccio-storage`.

## Container Network Contract

Compose defines two networks:

- `npm-cache-only`: internal network for dApp, wallet, and other Node
  containers when they run package-manager commands.
- `package-uplink`: normal network used by Verdaccio when it is temporarily
  unlocked and allowed to fetch approved packages from npmjs.

Verdaccio is attached to both networks. Package-installing app containers should
attach only to `npm-cache-only`; they can reach `http://verdaccio:4873/`, but
they cannot reach npmjs or the wider web directly from that network.

Use the Compose anchor for future app or wallet services:

```yaml
services:
  dapp:
    <<: *npm-cache-only
    build:
      context: .
    command: pnpm install --frozen-lockfile
```

The anchor sets package-manager registry environment variables to
`http://verdaccio:4873/` and blocks the direct `registry.npmjs.org` hostname as
a second line of defense. Runtime containers that need Stellar RPC/Horizon
access should install dependencies in a cache-only build/install step first,
then run the application in a separate runtime service with only the network
access it actually needs.

## Web Image

The production web image is built by `Dockerfile.web`:

```bash
DOCKER_BUILDKIT=0 docker compose build web
docker compose up -d web
```

The build stage installs `pnpm@9.15.9` and project dependencies from
`http://verdaccio:4873/` while attached to `medichain-npm-cache-only`. The
runtime service publishes container port `3000` to host port `3001` by default:

```text
http://localhost:3001
```

Set `WEB_PORT=3000` when port 3000 is available.

## Lock Modes

Locked mode is the default:

```bash
./lock-npmjs.sh
```

Locked mode uses `verdaccio-config.yaml`, which has no npmjs uplink. Verdaccio
serves only packages already present in its storage volume.

Unlocked mode is temporary:

```bash
./unlock-npmjs.sh
```

Unlocked mode uses `verdaccio-config.unlocked.yaml`, which enables the npmjs
uplink so approved packages can be fetched and cached.

## Package Approval Flow

1. Name the exact package and why it is needed.
2. Human approves the package.
3. Run `./unlock-npmjs.sh`.
4. Install through pnpm, for example `pnpm add @elenajs/core`.
5. Run `./lock-npmjs.sh`.

After changing the lockfile, seed the Verdaccio cache for locked Docker builds:

```bash
./unlock-npmjs.sh
docker run --rm --network medichain-npm-cache-only \
  -e NPM_CONFIG_REGISTRY=http://verdaccio:4873/ \
  -v "$PWD:$PWD" -w "$PWD" \
  stellar-dapp-workspace-template:latest \
  bash -lc 'pnpm fetch --force --store-dir /tmp/medichain-pnpm-store --registry http://verdaccio:4873/'
./lock-npmjs.sh
```

Then restore the workspace install from the normal local store if needed:

```bash
docker run --rm --network medichain-npm-cache-only \
  -e CI=true \
  -e NPM_CONFIG_REGISTRY=http://verdaccio:4873/ \
  -v "$PWD:$PWD" -w "$PWD" \
  stellar-dapp-workspace-template:latest \
  bash -lc 'pnpm install --frozen-lockfile --registry http://verdaccio:4873/'
```

Do not bypass Verdaccio by changing `.npmrc`, installing directly from a URL,
or using curl/wget to fetch packages.

## Inspection Helper

For an interactive metadata review and install:

```bash
./unlock-and-inspect.sh <package-name>
```

The helper unlocks Verdaccio, reads metadata through the local registry, prompts
for approval, installs with pnpm if approved, and re-locks Verdaccio on exit.
