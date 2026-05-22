# Pre-Flight Audit — Stellar dApp Template

**Date:** 2026-05-22
**Template:** Stellar dApp Workspace
**Dependencies checked:** Node.js 22+, Rust (wasm32 target), pnpm, Docker

---

## Core Capability Audit

### 1. Wallet Connection

**Check:** dApp can detect, connect to, and sign transactions with a Stellar wallet.

- [ ] Freighter `isConnected()` detection
- [ ] `setAllowed()` permission request
- [ ] `getPublicKey()` address retrieval
- [ ] `getNetwork()` network passphrase verification
- [ ] `signTransaction()` signing flow
- [ ] Disconnect and reconnect handling
- [ ] Multi-wallet support via Stellar Wallets Kit (optional)

### 2. Transaction Building

**Check:** Transactions are built with correct fee, timeout, network passphrase.

- [ ] Classic payment/asset operations via `TransactionBuilder`
- [ ] Soroban contract invocation with `Contract.call()`
- [ ] ScVal argument construction (Address, i128, Symbol, Vec, Struct)
- [ ] Fee set to `BASE_FEE` (100 stroops) minimum
- [ ] Timeout set (typically 180 seconds / 30 ledgers)
- [ ] Network passphrase from SDK constants (`Networks.TESTNET` / `Networks.PUBLIC`)
- [ ] No hardcoded passphrases or secret keys

### 3. Transaction Simulation (Soroban)

**Check:** Soroban transactions are simulated before submission.

- [ ] `rpc.simulateTransaction()` called before `sendTransaction()`
- [ ] Simulation errors checked via `Api.isSimulationError()`
- [ ] `assembleTransaction()` used to set proper resource values
- [ ] Resource fee applied from simulation results

### 4. Transaction Submission

**Check:** Signed transactions are submitted and confirmed correctly.

- [ ] Soroban txs submitted via `rpc.sendTransaction()`
- [ ] Classic txs submitted via `horizon.submitTransaction()`
- [ ] Confirmation polling with timeout (not infinite loop)
- [ ] Error handling: NOT_FOUND, ERROR, FAILED statuses
- [ ] Transaction hash displayed immediately after submission

### 5. Network Configuration

**Check:** Network switching between Testnet and Mainnet.

- [ ] `NEXT_PUBLIC_STELLAR_NETWORK` env var controls network
- [ ] Testnet Horizon: `https://horizon-testnet.stellar.org`
- [ ] Testnet RPC: `https://soroban-testnet.stellar.org`
- [ ] Mainnet RPC from env var (not hardcoded)
- [ ] Friendbot only enabled on Testnet

### 6. Error Handling

**Check:** Common errors have clear user-facing messages.

- [ ] Wallet not installed / not connected
- [ ] User rejected signing
- [ ] Insufficient XLM for fees
- [ ] Account not funded
- [ ] Network mismatch (wallet on wrong network)
- [ ] Transaction timeout / expired
- [ ] Simulation errors (resource, auth, contract)
- [ ] Double-submission prevention (loading state)

### 7. Security

**Check:** Sensitive data is handled securely.

- [ ] No private keys in client-side code
- [ ] No hardcoded secret keys or mnemonics
- [ ] Network passphrases from SDK constants
- [ ] Signing happens in wallet extension, not in app code
- [ ] Environment variables for API keys / RPC URLs
- [ ] `NEXT_PUBLIC_` prefix only on variables safe for client exposure

### 8. UX States

**Check:** All user interaction states are handled.

- [ ] Loading state during wallet connection
- [ ] Loading state during transaction signing
- [ ] Loading state during transaction submission
- [ ] Loading state during confirmation polling
- [ ] Success state with tx hash and optional StellarExpert link
- [ ] Error state with clear, actionable message
- [ ] Empty state (no wallet connected)
- [ ] Disabled state (form elements blocked during processing)

### 9. Rust / Soroban Toolchain

**Check:** Soroban contract development tools are available.

- [ ] `rustc` and `cargo` in PATH
- [ ] `wasm32-unknown-unknown` target installed
- [ ] `soroban-sdk` available as dependency
- [ ] `cargo test` runs contract tests
- [ ] `cargo build --target wasm32-unknown-unknown --release` produces `.wasm`

---

## Design Audit (web-prototype-taste-soft)

### 10. Floating Pill Nav

**Check:** Navigation uses floating glass pill, not edge-to-edge sticky bar.

- [ ] `width: max-content` (not `width: 100%`)
- [ ] `border-radius: 999px` (pill shape)
- [ ] `backdrop-filter: blur()` (frosted glass)
- [ ] Hairline ring via `box-shadow`, not `border`
- [ ] Gap from top edge (`margin-top`)

### 11. Section Padding

**Check:** Sections have generous breathing room.

- [ ] `padding` ≥ 96px per section
- [ ] Hero uses `min-height: 100dvh`
- [ ] Content max-width constrained for readability

### 12. Typography

**Check:** Fonts follow premium aesthetic rules.

- [ ] No Inter, Roboto, Helvetica, Open Sans
- [ ] Display weight ≥ 700
- [ ] No pure black `#000`

### 13. Motion

**Check:** Animations follow best practices.

- [ ] Custom cubic-bezier, no `linear` or `ease-in-out` (except marquee)
- [ ] Only `transform` and `opacity` animated (not width/height/top/left)
- [ ] `prefers-reduced-motion` respected
- [ ] Scroll entry via `IntersectionObserver`

---

## Audit Summary

| Category | Items |
|---|---|
| Wallet Connection | 7 |
| Transaction Building | 6 |
| Transaction Simulation | 4 |
| Transaction Submission | 6 |
| Network Configuration | 5 |
| Error Handling | 8 |
| Security | 7 |
| UX States | 8 |
| Rust Toolchain | 4 |
| Design | 4 |
| **Total** | **59** |
