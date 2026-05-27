# Development Environment

## Project Orientation

At Codex session start, read `ORIENTATION.md` from the workspace root and use
it as required project orientation context. It captures the intended agent role
for this workspace: a direct, proactive coding agent for Roger's Stellar
healthcare MVP that documents important design decisions, explains major
blockchain/product architecture choices, and asks before committing to major
ambiguous choices.

Keep `ORIENTATION_BRAINSTORM.md` as the source brainstorm record. The compiled
orientation in `ORIENTATION.md` is the active version future sessions should
load.

You are running inside a Docker sbx sandbox (microVM). The host provides
network filtering via `sbx policy`. You have full sudo access inside this
VM but cannot reach the host filesystem outside the workspace.

The human uses VS Code on the host to view and edit files. Changes you make
to workspace files appear in their editor instantly. Changes they make in
VS Code appear here instantly — the workspace is a direct filesystem mount.

## VS Code Security (host-side)

The sandbox shares the workspace filesystem with the host. VS Code MUST
open this workspace in **restricted mode** (untrusted workspace) to prevent
auto-execution of tasks, scripts, and extension commands that could be
planted by a compromised sandbox.

**Host command:**
```
code --disable-workspace-trust /path/to/stellar-dapp-workspace
```

- Tasks, debug configs, and extension auto-runs are disabled in restricted mode
- LSP (TypeScript) and syntax highlighting still work
- VS Code prompts before running any workspace-defined commands

## Toolchain

- pnpm (via corepack)
- Node.js 22+
- Rust (rustup + wasm32-unknown-unknown target) — for Soroban contracts
- Docker / Docker Compose for repo-owned local services such as Verdaccio
- Git

## Primary Dependencies

### Stellar SDK (JavaScript / TypeScript)

```bash
npm install @stellar/stellar-sdk @stellar/freighter-api
# Or for multi-wallet support:
npm install @stellar/stellar-sdk @creit.tech/stellar-wallets-kit
```

Import in components:
```js
import * as StellarSdk from "@stellar/stellar-sdk";
import {
  isConnected,
  getPublicKey,
  signTransaction,
} from "@stellar/freighter-api";
```

### Soroban Contracts (Rust)

Soroban smart contracts are written in Rust using the `soroban-sdk` crate.
The Rust toolchain and `wasm32-unknown-unknown` target are pre-installed
in the sandbox.

```toml
[dependencies]
soroban-sdk = "22.0"
soroban-token-sdk = "22.0"

[dev-dependencies]
soroban-sdk = { version = "22.0", features = ["testutils"] }
```

### Web Framework

The template supports Next.js (App Router) or plain React. The frontend
connects to Stellar via Horizon (classic) and RPC (Soroban).

**Next.js setup:**
```bash
pnpm create next-app stellar-dapp --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
```

## Stellar Dev Skills (reference)

The `stellar-dev/` directory contains reference skills for Stellar
blockchain development:

- **dapp/SKILL.md** — Frontend: wallet connection, tx building, contract invocation, React/Next.js patterns
- **soroban/SKILL.md** — Smart contracts: Rust SDK, storage, auth, testing, security, advanced patterns
- **assets/SKILL.md** — Asset management: trustlines, SAC bridge, SEP standards
- **data/SKILL.md** — Data APIs: RPC methods, Horizon endpoints, streaming, pagination
- **standards/SKILL.md** — SEPs, CAPs, ecosystem directory, DeFi protocols

These are read-only reference files. Read them when you need:
- Wallet integration patterns → `stellar-dev/skills/dapp/SKILL.md`
- Writing or reviewing a Soroban contract → `stellar-dev/skills/soroban/SKILL.md`
- Managing Stellar assets → `stellar-dev/skills/assets/SKILL.md`
- Querying chain state → `stellar-dev/skills/data/SKILL.md`
- SEP/CAP standards lookup → `stellar-dev/skills/standards/SKILL.md`

## open-design Skills (design reference)

The `open-design/` directory provides UI design reference skills:

- **saas-landing/** — Landing page patterns, hero sections, CTAs
- **dashboard/** — Dashboard layouts, data displays
- **pricing-page/** — Pricing table patterns
- **critique/** — Design critique framework
- **motion-frames/** — Animation patterns, transitions
- **web-prototype-taste-soft/** — Premium soft aesthetic design rules

These are read-only design assets. Read the relevant skill when designing UI.

## Environment Setup

Run these steps on first run or after a clean environment is created:

1. Start the repo-owned Verdaccio container:
   ```
   docker compose up -d verdaccio
   ```

   The default `verdaccio-config.yaml` is locked and has no npmjs uplink.
   Use `./unlock-npmjs.sh` only after a package is approved, then run
   `./lock-npmjs.sh` when the package has been cached.

2. Configure pnpm to use the local registry if `.npmrc` is not already active:
   ```
   pnpm config set registry http://localhost:4873
   ```

3. Install project dependencies (goes through verdaccio):
   ```
   pnpm install --frozen-lockfile
   ```

4. The environment is ready. Start the dev server or run tests as needed.

## Package Approval Protocol

Verdaccio runs as a Docker Compose service from this repository. It is locked
by default because `verdaccio-config.yaml` has no npmjs uplink. The unlocked
configuration is `verdaccio-config.unlocked.yaml` and should be used only
while installing an approved package.

Future dApp, wallet, or other Node containers that run package-manager commands
should use the `*npm-cache-only` Compose anchor. They must reach packages
through `http://verdaccio:4873/`, not npmjs directly.

See `docs/dependency-management.md` for the current operational details.

WHEN YOU NEED A NEW NPM PACKAGE:

1. Report to the human clearly:
   "I need package `<name>@<version>` for `<reason>`."

2. WAIT for the human to approve the package. They may inspect it before
   unlocking Verdaccio. Do not proceed until they confirm.

3. After approval, unlock Verdaccio and install the package:
   ```
   ./unlock-npmjs.sh
   pnpm add <name>
   ./lock-npmjs.sh
   ```

   This goes through Verdaccio, which fetches and caches the package.

DO NOT:
- Attempt to change npm registry config to bypass Verdaccio
- Use curl, wget, or any other tool to download packages directly
  instead of using the package manager through Verdaccio
- Edit Verdaccio config or `docker-compose.yml` without human instruction

## Stellar Network Configuration

The frontend connects to Stellar Testnet by default. Configure environment
variables for network selection:

```env
# .env.local
NEXT_PUBLIC_STELLAR_NETWORK=testnet
NEXT_PUBLIC_STELLAR_MAINNET_RPC_URL=
```

**Testnet endpoints:**
- Horizon: `https://horizon-testnet.stellar.org`
- RPC: `https://soroban-testnet.stellar.org`
- Friendbot: `https://friendbot.stellar.org`

**Mainnet endpoints:**
- Horizon: `https://horizon.stellar.org`
- RPC: Set via `NEXT_PUBLIC_STELLAR_MAINNET_RPC_URL` (choose a provider)

## Starting the Dev Server

Start the project's dev server:
```
pnpm dev
```

If the dev server runs inside a VM or remote container, bind to `0.0.0.0`
and publish the port using that environment's port-forwarding mechanism.

The Dockerized web runtime is built with `Dockerfile.web` and the repo-owned
Compose service:
```
DOCKER_BUILDKIT=0 docker compose build web
docker compose up -d web
```

It serves on `http://localhost:3001` by default. Set `WEB_PORT=3000` if port
3000 is free.

## Testing

### Frontend tests
```
pnpm test
```

### Soroban contract tests
```
cargo test
```

## File Modifications

- Changes to the workspace are live on the host filesystem.
- `node_modules/` is in the workspace and persisted across restarts.
- `target/` (Rust build artifacts) is in the workspace.
- `.sbx/` and `.od/` directories should be gitignored.

## What You Can Do

- Run pnpm, node, cargo, git, docker compose, docker
- Install system packages with sudo apt-get
- Modify any file in the workspace
- Run tests, linters, build commands
- Deploy Soroban contracts (via Stellar CLI or RPC)
- Create git commits and branches

## What Is Blocked (by host proxy)

- Direct package installation from npmjs.org outside Verdaccio
- Access to host filesystem outside the workspace

## Quick Reference: Stellar Packages

| Package | Purpose |
|---------|---------|
| `@stellar/stellar-sdk` | Core JS SDK: tx building, Horizon, RPC |
| `@stellar/freighter-api` | Freighter browser wallet connection |
| `@creit.tech/stellar-wallets-kit` | Multi-wallet modal (Freighter, LOBSTR, xBull) |
| `smart-account-kit` | Passkey-based smart accounts |
| `@openzeppelin/relayer-plugin-channels` | Gasless tx submission |
