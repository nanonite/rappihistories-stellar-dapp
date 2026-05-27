# Dev Workflow - Stellar dApp

## Architecture

```text
Host or development VM
  VS Code / editor
  Browser with Freighter wallet
  Docker Compose
    - medichain-verdaccio on http://127.0.0.1:4873
    - npm-cache-only internal network for package installs
    - package-uplink network for Verdaccio-only npmjs fetches
  Workspace
    - Next.js app in src/
    - Soroban contracts in contracts/
    - Stellar and design references
```

Verdaccio is now a repository-owned Docker Compose service. Package approval
does not depend on an sbx-managed container or `sbx policy`; the lock state is
controlled by which Verdaccio config file the container is running.

## 1. Start Local Services

Start Verdaccio in locked mode:

```bash
docker compose up -d verdaccio
```

Check status:

```bash
docker compose ps verdaccio
docker compose logs -f verdaccio
```

Configure pnpm if needed. The repo `.npmrc` already points at Verdaccio:

```bash
pnpm config set registry http://localhost:4873
```

Install dependencies:

```bash
pnpm install --frozen-lockfile
```

If a clean machine has an empty Verdaccio cache, approve the existing lockfile
dependencies first, run `./unlock-npmjs.sh`, run the install, then re-lock with
`./lock-npmjs.sh`.

## 2. Start the Dev Server

For local Node development:

```bash
pnpm dev
```

Open `http://localhost:3000`.

If the app runs inside a VM or remote container, bind to `0.0.0.0` and use that
environment's normal port-forwarding command:

```bash
pnpm dev --hostname 0.0.0.0
```

For the Dockerized web runtime:

```bash
DOCKER_BUILDKIT=0 docker compose build web
docker compose up -d web
```

Open `http://localhost:3001` by default. Override with `WEB_PORT=3000` if port
3000 is free:

```bash
WEB_PORT=3000 docker compose up -d web
```

The web image builds on the internal `medichain-npm-cache-only` network and
installs dependencies from locked Verdaccio. Use the classic Docker builder for
this build path because the default BuildKit builder does not attach to the
custom internal network in this environment.

## 3. Installing New Packages

Default state: locked. `verdaccio-config.yaml` has no npmjs uplink, so
Verdaccio serves only packages already present in its storage volume.

Approval flow:

1. Agent reports the exact package and reason.
2. Human approves the package.
3. Unlock Verdaccio:

```bash
./unlock-npmjs.sh
```

4. Install through pnpm so the package is cached by Verdaccio:

```bash
pnpm add <pkg>
```

5. Re-lock Verdaccio:

```bash
./lock-npmjs.sh
```

The scripts recreate only the Verdaccio container. The named Docker volume
`verdaccio-storage` persists cached package tarballs and metadata.

Any future dApp or wallet Docker container that runs package-manager commands
should use the `*npm-cache-only` Compose anchor. That gives it
`http://verdaccio:4873/` as the npm registry and puts it on an internal network
where it cannot fetch npm packages directly from the web.

Current cached build/runtime packages include the existing Next/Stellar
lockfile dependencies, `@elenajs/core@1.0.0`, and the pinned build tool
`pnpm@9.15.9`.

See `docs/dependency-management.md` for the dedicated dependency approval
reference.

## 4. Stellar Wallet Setup

The dApp connects to Stellar wallets through Freighter or Stellar Wallets Kit.

Freighter development setup:

1. Install the Freighter browser extension.
2. Create or import a Testnet wallet.
3. Fund with Friendbot: `https://friendbot.stellar.org?addr=<YOUR_PUBLIC_KEY>`.

Wallet private keys stay in the browser extension. They should never enter the
workspace, app source, environment variables, logs, or test fixtures.

## 5. Development Cycle

Frontend:

1. Write components following patterns in `stellar-dev/skills/dapp/SKILL.md`.
2. Use `@stellar/stellar-sdk` for transaction building and chain queries.
3. Sign transactions through the wallet.
4. Submit Soroban transactions to RPC and classic operations to Horizon.

Soroban contracts:

```bash
cargo build --target wasm32-unknown-unknown --release
cargo test
```

Transaction flow:

```text
User action -> build tx -> simulate Soroban tx -> sign -> submit -> confirm
```

## 6. Security Notes

- Verdaccio binds to `127.0.0.1:4873` on the Docker host.
- Locked mode has no npmjs uplink in Verdaccio config.
- Do not bypass Verdaccio by changing `.npmrc` or installing directly from a URL.
- Testnet is the default network; mainnet requires explicit env configuration.
- Network passphrases must come from SDK constants, not hardcoded strings.
- Clinical content and patient identity should remain encrypted off-chain.
