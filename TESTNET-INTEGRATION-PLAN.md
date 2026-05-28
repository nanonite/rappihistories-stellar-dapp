# Testnet Integration Plan

This plan turns the local stellar-local manual MVP into a publicly demoable
Tier 3 MVP on Stellar Testnet, hosted across Cloudflare for off-chain services.
It is intentionally scoped to the Tier 3 spine — patient registers an encrypted
record, patient grants a clinician, clinician obtains a KMS release and fetches
ciphertext, patient revokes, future requests return `REVOKED` — plus the new
Option A append flow (clinician appends to patient history under a Write grant).

The plan starts **after** the local manual MVP is signed off and the
`mvp-local-baseline` tag is in place (see Baseline Snapshot section below).
Local stellar-local remains the canonical fast-iteration target; Testnet is a
separate, additive workstream.

## Goals

- Two-browser demo: a patient browser and a clinician browser, each connected
  with their own wallet, interacting with the same contracts on Stellar Testnet.
- Patient grants the clinician read access; clinician fetches ciphertext via a
  wallet-signed KMS release and decrypts it locally; patient revokes; next
  clinician request returns `REVOKED`.
- Patient grants the clinician write access; clinician appends a note that the
  patient sees attributed to the clinician; patient revokes write; clinician
  cannot append again.
- All off-chain services (api-indexer, kms-gate, object storage) reachable from
  the public web app without local Docker.
- Reset/redeploy runbook with documented commands, env vars, and expected
  output so any operator can rebuild the demo from a clean state.

## Non-Goals

- Mainnet deployment. Mainnet requires a separate threat-model and ops review.
- Real PKI / regulated KMS. The Testnet demo uses a wallet-signed gate around
  a managed key store; it is forward-only by design.
- Tier 1/Tier 2/break-glass/prescription/supply-chain on Testnet. They remain
  in the local rehearsal until the Tier 3 spine is proven on Testnet.
- Per-tenant onboarding flows, billing, or production observability.

## Architecture (Testnet Shape)

```
+------------------+        +-------------------+
| Patient browser  |        | Clinician browser |
|  (Cloudflare     |        |  (same web app)   |
|   Pages)         |        |                   |
+---+----------+---+        +---+-----------+---+
    |          |                |           |
    | wallet   | https          | wallet    | https
    | sign     |                | sign      |
    v          v                v           v
+-------+   +----------------+   +----------------------+
| Stellar|  | api-indexer    |   | kms-gate             |
| Testnet|  | (Fly.io or     |   | (Fly.io or Cloudflare|
| RPC    |  |  Cloudflare    |   |  Worker; managed key |
|        |  |  Worker)       |   |  storage backend)    |
+--------+  +-------+--------+   +-----------+----------+
                    |                        |
                    v                        v
              +-----------+            +-----------+
              | Postgres  |            | Cloudflare|
              | (managed) |            | R2        |
              +-----------+            | (cipher-  |
                                       |  text)    |
                                       +-----------+
```

Web app, R2, and Pages live on Cloudflare. api-indexer needs a long-lived
Postgres connection and event polling, so Fly.io is the default target; a
Cloudflare Worker variant is acceptable if event polling is reframed as a
scheduled trigger. kms-gate has the same shape and the same default.

## Workstreams

### A. Contracts on Testnet (MVP-TN-2)

- Build the wasm artifacts from the contracts submodule and deploy via
  `stellar contract deploy --network testnet`.
- Fund deploy/admin and seed identity accounts via Friendbot.
- Record contract IDs in a committed `testnet.env.example` template; secrets
  go in an untracked `.env.testnet` consumed by deploy scripts.
- Smoke-test each contract entry point against Testnet RPC with the existing
  CLI bindings (no web app yet).

### B. Web — Stellar Wallets Kit (MVP-TN-3)

- Replace the localStorage-based `useWallet` hook with `@creit.tech/stellar-wallets-kit`.
- Support Freighter, xBull, Albedo at minimum. Patient and clinician each pick
  their own wallet on their browser.
- Persist only the public key + selected wallet id locally; never store secrets.

### C. Web — Real Soroban RPC Calls (MVP-TN-4)

- Replace the placeholder `lib/contract.ts` with calls through `@stellar/stellar-sdk`'s
  `Contract` / `TransactionBuilder` / `rpc.Server`.
- Build, sign (via wallet), submit, and poll each transaction with proper auth.
- Use the deployed Testnet contract IDs and Testnet passphrase
  `Test SDF Network ; September 2015`.
- Cover: register_record, create_grant, create_write_grant, append_record,
  revoke_grant, revoke_write_grant.

### D. Web — R2 Storage Adapter + Presigned URLs (MVP-TN-5)

- Encrypt clinical payloads client-side; upload ciphertext to Cloudflare R2 via
  short-lived presigned URLs.
- The locator stored on-chain is the R2 object key; commitment is the SHA-256
  of the ciphertext.
- Read flow: web app gets a presigned GET URL from api-indexer (or a tiny
  dedicated service) only after kms-gate has approved the release.

### E. Web — Testnet Env Config (MVP-TN-6)

- `NEXT_PUBLIC_STELLAR_NETWORK=testnet`, RPC URL, contract IDs, indexer base
  URL, kms-gate base URL, R2 public host all surfaced as build-time public env.
- Local stellar-local config remains the default for `pnpm dev`; testnet is
  selected by a separate build target (`pnpm build:testnet`). No runtime
  selector.

### F. api-indexer — Public Deploy + Testnet RPC (MVP-TN-7)

- Deploy to Fly.io with managed Postgres (Neon/Supabase/Fly Postgres).
- Configure event ingestor to read from Testnet RPC.
- Backfill from the contract deploy ledger forward; document reset procedure.
- Expose only the read endpoints needed by the web app (history, grants,
  records, write-grants). All endpoints rate-limited and CORS-restricted to
  the Cloudflare Pages origin.

### G. kms-gate — Public Deploy + Wallet-Signed Release (MVP-TN-8)

- Deploy to Fly.io alongside api-indexer.
- Release predicate inputs unchanged: requester == caller, grant exists, not
  revoked, not vetoed, reveal_at <= now < expires_at.
- Authenticate the requester by verifying a wallet-signed challenge (nonce +
  release-request payload signed with the requester's Stellar key).
- Forward-only key store: managed cloud KMS or a sealed-box envelope with the
  master key in Cloudflare Workers KV. Revoke means future requests are
  rejected; it does not erase issued bytes. This is documented as an
  instructive demo limitation.

### H. Cloudflare Hosting Plan (MVP-TN-9)

- Cloudflare Pages: web app build, custom subdomain.
- Cloudflare R2: ciphertext bucket with bucket-level CORS, no public listing,
  presigned URL access only.
- Cloudflare Tunnel (optional): only if api-indexer/kms-gate are kept on-prem
  for the first demo; default is Fly.io.
- DNS records, TLS certs, environment-specific secrets managed in the
  Cloudflare dashboard (no secrets in the repo).

### I. Two-Browser Demo Runbook + Reset Tooling (MVP-TN-10)

Required content:

1. Pre-demo checklist: contract IDs match, Friendbot has funded both wallets,
   api-indexer is caught up, kms-gate health endpoint green, R2 bucket empty.
2. Step-by-step click path for the patient browser and the clinician browser,
   with expected indexer state and kms-gate decisions at each step.
3. Reset script that: clears R2 objects from the demo prefix, truncates the
   demo schema in api-indexer Postgres, re-runs the patient/clinician seed
   identities, prints the new contract state hash.
4. Known limits printed at the top of the runbook (forward-only KMS,
   single-tenant demo, no break-glass on Testnet).

### J. Baseline Tag (Local) (MVP-TN-11)

The local baseline is the precondition for starting the Testnet workstream.
See the Baseline Snapshot section.

## Baseline Snapshot Procedure

Once the local manual browser demo (#74) is fully proven — including the
append flow added under #83 — declare a baseline:

1. In each submodule (`components/contracts`, `components/packages`,
   `components/api-indexer`, `components/kms-gate`, `components/web`):
   `git tag -a mvp-local-baseline -m "Manual local MVP baseline"` and
   `git push origin mvp-local-baseline`.
2. In the root repo: bump every submodule pointer to the tagged commit, commit
   the bumps, then `git tag -a mvp-local-baseline -m "Manual local MVP baseline (root)"`
   and `git push origin mvp-local-baseline`.
3. Snapshot the workspace for offline use: a tarball of the root repo at the
   tag with submodules initialized (`git clone --recurse-submodules` from the
   tag works for any operator; the tarball is just a convenience).

The Testnet workstream branches off `mvp-local-baseline`. Local stellar-local
work continues on `master`; any local fix that needs to flow into the Testnet
branch is cherry-picked, not the other way around.

## Sequencing

```
mvp-local-baseline tag (MVP-TN-11)
  └── MVP-TN-2 contracts deploy
        └── MVP-TN-7 api-indexer deploy
        └── MVP-TN-8 kms-gate deploy
              └── MVP-TN-3 web wallets kit
                    └── MVP-TN-4 web real RPC calls
                          └── MVP-TN-5 web R2 adapter
                                └── MVP-TN-6 web testnet env
                                      └── MVP-TN-9 Cloudflare hosting
                                            └── MVP-TN-10 demo runbook
```

MVP-TN-1 (#76) is the umbrella that already exists and remains the parent for
the whole Testnet series.

## Out of Scope (Track Separately)

- Stellar mainnet deployment.
- Break-glass and prescription flows on Testnet.
- Production-grade KMS, HSM, or per-tenant key isolation.
- Real patient onboarding, consent management, or regulated identity issuance.
- Observability, alerting, and incident response.
