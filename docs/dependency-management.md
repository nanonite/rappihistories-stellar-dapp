# Dependency Management

## Verdaccio Service

The project uses an e2e-owned Verdaccio Docker container as the npm
registry/cache.

```bash
docker compose -f e2e/docker-compose.yml up -d verdaccio
```

The web component `.npmrc` points pnpm to:

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
    command: cd components/web && pnpm install --frozen-lockfile
```

The anchor sets package-manager registry environment variables to
`http://verdaccio:4873/` and blocks the direct `registry.npmjs.org` hostname as
a second line of defense. Runtime containers that need Stellar RPC/Horizon
access should install dependencies in a cache-only build/install step first,
then run the application in a separate runtime service with only the network
access it actually needs.

## Web Image

The production web image is built by `components/web/Dockerfile`:

```bash
DOCKER_BUILDKIT=0 docker compose -f e2e/docker-compose.yml build web
docker compose -f e2e/docker-compose.yml up -d web
```

The build stage installs `pnpm@9.15.9` and project dependencies from
`http://verdaccio:4873/` while attached to `medichain-npm-cache-only`. The
runtime service publishes container port `3000` to host port `3001` by default:

```text
http://localhost:3001
```

Set `WEB_PORT=3000` when port 3000 is available.

## Nix Contract Toolchain Boundary

`components/contracts/flake.nix` defines only the Soroban contract toolchain:
Rust/Cargo with the `wasm32-unknown-unknown` target, Rust formatting/lint
support, Binaryen, and native build/link tools needed by contract crates. Use
it locally with:

```bash
cd components/contracts
nix develop
```

Use the CI-flavored shell locally when you want the same stricter tool set for
contract verification:

```bash
cd components/contracts
nix develop .#ci
```

This flake intentionally does not include Node.js, pnpm, Docker, Docker Compose,
or backend/KMS service runtimes. Node dependency installs still use the
Verdaccio approval and cache flow in this document. Web/dApp work remains on
the Docker plus Verdaccio path; service toolchains should get their own
component-owned container or flake only when their boundaries justify it.

See [`docs/nix-toolchain.md`](nix-toolchain.md) for contract validation commands.

## Lock Modes

Locked mode is the default:

```bash
components/web/lock-npmjs.sh
```

Locked mode uses `components/web/verdaccio-config.yaml`, which has no npmjs
uplink. Verdaccio serves only packages already present in its storage volume.

Unlocked mode is temporary:

```bash
components/web/unlock-npmjs.sh
```

Unlocked mode uses `components/web/verdaccio-config.unlocked.yaml`, which
enables the npmjs uplink so approved packages can be fetched and cached.

## Package Approval Flow

1. Name the exact package and why it is needed.
2. Human approves the package.
3. Run `components/web/unlock-npmjs.sh`.
4. Install through pnpm, for example `pnpm add @elenajs/core`.
5. Run `components/web/lock-npmjs.sh`.

After changing the lockfile, seed the Verdaccio cache for locked Docker builds:

```bash
components/web/unlock-npmjs.sh
docker run --rm --network medichain-npm-cache-only \
  -e NPM_CONFIG_REGISTRY=http://verdaccio:4873/ \
  -v "$PWD:$PWD" -w "$PWD/components/web" \
  web-dev-template:latest \
  bash -lc 'pnpm fetch --force --store-dir /tmp/medichain-pnpm-store --registry http://verdaccio:4873/'
components/web/lock-npmjs.sh
```

For e2e, keep a separate Verdaccio runtime but clone the already-approved
development cache into the e2e storage volume before a from-scratch run:

```bash
e2e/up.sh
```

This copies package storage only. The e2e Verdaccio service still mounts the
checked-in `components/web/verdaccio-config.yaml` locked config and does not
gain an npmjs uplink during normal test runs.

The order matters: Compose builds images before starting application services,
so a single `docker compose up --build` cannot rely on the `verdaccio` service
being available during the build. `e2e/up.sh` starts locked e2e Verdaccio first,
then builds images against `127.0.0.1:${E2E_VERDACCIO_PORT:-4874}`.

Then restore the workspace install from the normal local store if needed:

```bash
docker run --rm --network medichain-npm-cache-only \
  -e CI=true \
  -e NPM_CONFIG_REGISTRY=http://verdaccio:4873/ \
  -v "$PWD:$PWD" -w "$PWD/components/web" \
  web-dev-template:latest \
  bash -lc 'pnpm install --frozen-lockfile --registry http://verdaccio:4873/'
```

Do not bypass Verdaccio by changing `.npmrc`, installing directly from a URL,
or using curl/wget to fetch packages.

## Inspection Helper

For an interactive metadata review and install:

```bash
components/web/unlock-and-inspect.sh <package-name>
```

The helper unlocks Verdaccio, reads metadata through the local registry, prompts
for approval, installs with pnpm if approved, and re-locks Verdaccio on exit.
