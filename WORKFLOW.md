# Dev Workflow — Stellar dApp

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Host (your machine)                                      │
│                                                            │
│  VS Code ── virtiofs mount ──► Workspace                  │
│  sbx ports --publish 3000:3000 (port forward)              │
│  Brave/Chrome ──► localhost:3000                           │
│  Freighter Wallet (browser extension)                      │
└──────────────────┬───────────────────────────────────────┘
                   │ sandbox boundary
┌──────────────────▼───────────────────────────────────────┐
│  stellar-dapp (microVM)                                    │
│                                                            │
│  pnpm dev ──► Next.js dev server                           │
│               ▼ http://0.0.0.0:3000                        │
│  stellar-dev/skills/ (Stellar reference)                    │
│  open-design/skills/ (UI design reference)                  │
│  verdaccio (local npm cache on :4873)                      │
│                                                            │
│  Rust / cargo ──► Soroban contract compilation             │
│               ▼ wasm32-unknown-unknown target               │
└──────────────────────────────────────────────────────────┘
```

## 1. Start the Sandbox and Dev Environment

### Step 1: Start the sandbox (host)

```bash
sbx run stellar-dapp
```

Other sandbox commands:

```bash
sbx stop stellar-dapp    # pause (VM state preserved)
sbx rm stellar-dapp      # destroy (workspace files on host untouched)
sbx reset                # destroy everything including cached images
```

### Step 2: Start the dev server (inside sandbox)

```bash
pnpm dev --hostname 0.0.0.0
```

### Step 3: Publish the port (host)

```bash
sbx ports stellar-dapp --publish 3000:3000
```

Check forwarded ports:
```bash
sbx ports stellar-dapp
sbx list
```

## 2. Stellar Wallet Setup

The dApp connects to Stellar wallets through the Freighter browser
extension or Stellar Wallets Kit (multi-wallet).

### Freighter (recommended for development)

1. Install [Freighter browser extension](https://freighter.app)
2. Create or import a Testnet wallet
3. Fund with Friendbot: `https://friendbot.stellar.org?addr=<YOUR_PUBLIC_KEY>`

### Testing wallet connection

The dApp should provide a "Connect Wallet" button that:
1. Checks if Freighter is installed (`isConnected()`)
2. Requests permission (`setAllowed()`)
3. Retrieves the public key (`getPublicKey()`)
4. Verifies the network matches your config

## 3. Development Cycle

### Frontend (Next.js / React)

1. Write components following patterns in `stellar-dev/skills/dapp/SKILL.md`
2. Use `@stellar/stellar-sdk` for tx building and chain queries
3. Sign transactions through the wallet (Freighter or Wallets Kit)
4. Submit to Testnet RPC for Soroban txs, Horizon for classic txs

### Soroban Contract (Rust)

1. Create contract project: `cargo new --lib my-contract && cd my-contract`
2. Add `soroban-sdk` dependency to `Cargo.toml`
3. Write contract following patterns in `stellar-dev/skills/soroban/SKILL.md`
4. Build: `cargo build --target wasm32-unknown-unknown --release`
5. Test: `cargo test`

### UI Design

When building the dApp interface, reference `open-design/skills/`:

| Task | Skill |
|------|-------|
| Landing page | `open-design/skills/saas-landing/SKILL.md` |
| Dashboard | `open-design/skills/dashboard/SKILL.md` |
| Pricing | `open-design/skills/pricing-page/SKILL.md` |
| Design review | `open-design/skills/critique/SKILL.md` |
| Animations | `open-design/skills/motion-frames/SKILL.md` |
| Premium aesthetic | `open-design/skills/web-prototype-taste-soft/SKILL.md` |

## 4. Transaction Workflow

```
User Action → Build Tx → Simulate (Soroban) → Sign (Wallet) → Submit → Confirm
```

1. **Build**: Create transaction with proper fee, timeout, and operations
2. **Simulate** (Soroban only): Get resource estimates via `rpc.simulateTransaction()`
3. **Sign**: User signs in Freighter / wallet extension
4. **Submit**: Send signed XDR to RPC (Soroban) or Horizon (classic)
5. **Confirm**: Poll for transaction status and display result

## 5. Installing New Packages

The sandbox has **no internet access** to npmjs.org by default.

1. Tell the agent which package you need
2. Agent requests unlock from you
3. You unlock npmjs: `./unlock-npmjs.sh`
4. Agent installs via `pnpm add <pkg>` (goes through verdaccio)
5. You re-lock npmjs: `./lock-npmjs.sh`

## 6. Security Notes

- The dev server only listens on `0.0.0.0` inside the sandbox
- `sbx ports` creates a per-process forward, not a global port open
- Wallet private keys never touch the sandbox — signing happens in the browser extension
- Testnet-only by default; mainnet requires explicit env var configuration
- Network passphrase must always come from SDK constants, never hardcoded
- Verdaccio is local-only, bound to `0.0.0.0:4873`
- open-design and stellar-dev skills contain no executable code — pure markdown
