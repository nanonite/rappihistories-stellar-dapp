# MediChain MVP — Implementation Task Breakdown

## Context

This document is the implementation task breakdown for the MediChain Stellar/Soroban healthcare MVP, derived from `docs/claude/stellar-integrated-health-supply-plan_final.md` and the existing codebase. It is formatted for handoff to a tech lead as a structured set of Chainlink/project-management tasks with explicit blockers and acceptance criteria.

**What this is:** A complete, ordered set of tasks covering every layer of the MVP — monorepo infrastructure, five Soroban contracts, three Node services, shared TypeScript packages, a Next.js frontend, and an E2E test suite.

**What is already done:**
- Architecture and ADR documentation (comprehensive, in `docs/`)
- One working Soroban contract (`contracts/medical-record/`) — functional but deprecated by this plan
- Next.js frontend scaffold at `src/` with mock data (no real contract calls)
- Docker Compose with Verdaccio npm cache
- Wallet hook using `prompt()` (must be replaced with Freighter)

**The single most important implementation rule:** *Stub the decentralization, never stub the predicate.* The KMS key store can be a single-service MVP stub. The access predicate — `committed grant exists AND grantee == caller AND NOT revoked AND NOT vetoed AND revealAt <= now AND now < expiresAt` — must be real and enforced on every key release from day one.

**PHI rule:** Clinical content, patient name, diagnosis text, and medication names must never appear in any contract argument, return value, or event. Only hashes, commitments, pseudonymous IDs, locators, and supply-chain facts go on-chain.

---

## Prerequisites (before any task starts)

1. **Package approval:** New npm dependencies go through Verdaccio. Run `./unlock-npmjs.sh`, install, then `./lock-npmjs.sh`. Packages needed across the plan: `@stellar/freighter-api`, `minio` (or AWS S3 SDK), a lightweight HTTP framework for Node services, `qrcode`, `tweetnacl` (or use stellar-sdk's crypto). Check Verdaccio cache first.
2. **Stellar tooling:** The `stellar-dev/skills/` directory contains reference skills for Soroban contract development. Read `stellar-dev/skills/soroban/SKILL.md` before writing any contract code. Skills are also installed as Claude Code slash commands — use `/stellar-soroban`, `/stellar-dapp`, etc.
3. **Design references:** `open-design/skills/` contains UI design references. Use `/design-dashboard`, `/design-saas-landing`, etc. for all new pages — the frontend must not look like a generic crypto demo.
4. **Environment:** `.env.local` has `NEXT_PUBLIC_STELLAR_NETWORK=testnet` and `NEXT_PUBLIC_MEDICAL_CONTRACT_ID`. New contract IDs will be added here and to a shared Docker volume as the contracts are deployed.

---

## Epic Index

| ID  | Epic                      | Covers                                                    |
|-----|---------------------------|-----------------------------------------------------------|
| INF | Infrastructure & Monorepo | Workspace restructure, Docker, local chain, Verdaccio     |
| DOM | Domain Package            | Shared TypeScript types, predicate logic                  |
| IDB | Identity Contract         | Credential registry on Soroban                            |
| BKR | Access Broker Contract    | Core policy + audit contract                              |
| KMS | KMS Gate Service          | Key-release predicate service (stub)                      |
| STR | Storage & Crypto          | MinIO + envelope encryption                               |
| IDX | API-Indexer Service       | Event indexer, Postgres projections, workflows            |
| WLT | Wallet Integration        | Freighter replacement                                     |
| T3  | Tier 3 — Full History     | Normal patient-consent record flow                        |
| T2  | Tier 2 — Break-Glass      | Emergency bundle + veto window                            |
| T1  | Tier 1 — Offline Card     | Signed offline emergency card                             |
| RX  | Prescription Contract     | Prescription bridge state machine                         |
| SC  | Supply-Chain Contract     | Drug provenance, cold-chain, custody                      |
| WEB | Web App Integration       | UI for all roles                                          |
| E2E | End-to-End Tests          | Conformance and security tests                            |

---

## EPIC INF — Infrastructure & Monorepo Restructure

**Goal:** Convert the single Next.js app into the full monorepo layout, start all Docker services, and establish a local Stellar network. Everything else depends on this epic.

---

### INF-1 — Convert root to pnpm monorepo with workspaces

**Estimate:** 2 days
**Blocked by:** Nothing — this is the first task

**Acceptance Criteria:**
- `pnpm-workspace.yaml` defines `apps/*`, `packages/*`, `e2e`
- `pnpm install` from root resolves all packages through Verdaccio
- `pnpm -r build` succeeds (web app + placeholder packages)
- TypeScript project references wired so `packages/*` can be imported in `apps/*` without path hacks
- Root `tsconfig.json` uses `references` array; each package has its own `tsconfig.json` with `composite: true`

**Technical Notes:**
- Current root `package.json` at `package.json` grows a `"workspaces"` field; `pnpm-workspace.yaml` is the canonical source for pnpm
- Move `src/` → `apps/web/src/`; update `next.config.js`, `tailwind.config.js`, `postcss.config.js` to live under `apps/web/`
- Move root `tsconfig.json` to base config; `apps/web/tsconfig.json` extends it
- Existing `.npmrc` already points to `http://localhost:4873/` — confirm it still resolves through Verdaccio after restructure

---

### INF-2 — Scaffold package and app skeletons

**Estimate:** 1 day
**Blocked by:** INF-1

**Acceptance Criteria:**
- All directories exist with a valid `package.json` + `tsconfig.json`:
  - `packages/domain`, `packages/crypto`, `packages/storage`, `packages/stellar-client`, `packages/wallet`, `packages/test-fixtures`
  - `apps/web`, `apps/api-indexer`, `apps/kms-gate`
  - `e2e/`
- Each package exports at least one placeholder symbol so TypeScript can resolve imports
- `pnpm -r typecheck` passes with zero errors on skeleton files

**Technical Notes:**
- Package scope: `@medichain/domain`, `@medichain/crypto`, etc.
- Each `package.json`: `"main": "dist/index.js"`, `"types": "dist/index.d.ts"`, `"scripts": { "build": "tsc", "typecheck": "tsc --noEmit" }`
- `packages/domain/src/index.ts` exports `export const DOMAIN_VERSION = '0.1.0'` as a smoke-test placeholder

---

### INF-3 — Expand Docker Compose: postgres, minio, stellar-local, api-indexer, kms-gate

**Estimate:** 2 days
**Blocked by:** INF-1

**Acceptance Criteria:**
- `docker compose up` starts all 8 services without manual intervention: `verdaccio`, `web`, `api-indexer`, `kms-gate`, `postgres`, `minio`, `stellar-local`, `contract-runner`
- Postgres healthcheck passes (`pg_isready`)
- MinIO healthcheck passes (HTTP 200 on `/minio/health/live`)
- `stellar-local` starts the Quickstart image and exposes Soroban RPC on port 8000
- `contract-runner` is a short-lived container that deploys contracts on startup then exits 0
- None of the new services reach `registry.npmjs.org` directly (all npm traffic through Verdaccio)

**Technical Notes:**
- Current `docker-compose.yml` has `web` and `verdaccio` only — add all new services here
- `stellar-local`: `stellar/quickstart:testing` image, `--enable-soroban-rpc` flag
- Postgres: `postgres:16-alpine`, volume `postgres-data`, env `POSTGRES_DB=medichain POSTGRES_USER=medichain POSTGRES_PASSWORD=medichain`
- MinIO: `minio/minio:latest`, volume `minio-data`, command `server /data --console-address ":9001"`, env `MINIO_ROOT_USER=medichain MINIO_ROOT_PASSWORD=medichain`
- Add `Dockerfile.api-indexer` and `Dockerfile.kms-gate` following the pattern of `Dockerfile.web` — both Node 20 images, install via Verdaccio
- `STELLAR_RPC_URL=http://stellar-local:8000` injected into `api-indexer` and `kms-gate`

---

### INF-4 — Soroban contract workspace (Cargo workspace)

**Estimate:** 1 day
**Blocked by:** INF-1

**Acceptance Criteria:**
- `contracts/Cargo.toml` is a workspace manifest listing all 5 contracts as members
- `cargo build --release --target wasm32-unknown-unknown` from `contracts/` succeeds for all contracts
- Each new contract directory contains `src/lib.rs`, `src/types.rs`, `src/storage.rs`, `src/events.rs`, `src/errors.rs`, `src/test.rs`
- All 5 contracts compile to `.wasm` without warnings

**Technical Notes:**
```toml
# contracts/Cargo.toml
[workspace]
members = ["medical-record", "identity", "access-broker", "prescription", "supplychain", "incentive"]
resolver = "2"
[workspace.dependencies]
soroban-sdk = "22.0"
```
- New contracts alongside existing `medical-record/`: `identity/`, `access-broker/`, `prescription/`, `supplychain/`, `incentive/`
- Each new contract's `Cargo.toml` pins `soroban-sdk = { workspace = true }` — do not let individual contracts drift from the workspace version
- `medical-record` contract remains compilable but is deprecated; do not extend it

---

### INF-5 — Contract deployment script and seed data runner

**Estimate:** 1 day
**Blocked by:** INF-3, INF-4

**Acceptance Criteria:**
- `contract-runner` container deploys all 5 contracts to `stellar-local` on startup
- Contract IDs written to shared volume at `/shared/contract-ids.json` that `api-indexer` and `kms-gate` mount
- Seed script creates: 1 admin, 2 patients, 2 clinicians, 1 pharmacy, 1 responder — all funded on local network
- `api-indexer` reads contract IDs from the shared volume at startup and logs them

**Technical Notes:**
- Use `soroban contract deploy` CLI via toolchain in `stellar-dev/`
- Script lives at `scripts/deploy-contracts.sh`; `Dockerfile.contract-runner` calls it
- `contract-ids.json` shape: `{ "identity": "C...", "accessBroker": "C...", "prescription": "C...", "supplychain": "C...", "incentive": "C..." }`
- Seed data in `apps/api-indexer/src/seed/seed.ts` — runs only when `NODE_ENV=development` and database is empty

---

## EPIC DOM — Domain Package (`packages/domain`)

**Goal:** Single canonical TypeScript type library shared by all apps and packages. No runtime dependencies. The release predicate as a pure function lives here so KMS, tests, and indexer all evaluate the same predicate logic.

---

### DOM-1 — Core clinical and access types

**Estimate:** 1 day
**Blocked by:** INF-2

**Acceptance Criteria:**
- `packages/domain/src/clinical-history.ts` exports all tier and record types
- `packages/domain/src/access.ts` exports grant, capability, presence-proof, and credential types
- `packages/domain/src/audit.ts` exports online and delayed-offline audit event types
- Zero any-casts; strict TypeScript

**Technical Notes:**
```typescript
// packages/domain/src/clinical-history.ts
export type ClinicalHistoryTier =
  | 'offline_emergency_card'
  | 'online_emergency_bundle'
  | 'full_clinical_history';

export type RecordCategory =
  | 'allergy' | 'medication' | 'condition' | 'procedure'
  | 'lab' | 'imaging' | 'note' | 'immunization' | 'prescription'
  | 'behavioral_health' | 'reproductive_health' | 'substance_use';

export interface RecordLocator {
  locatorType: 'url' | 's3' | 'ipfs' | 'institutional_reference' | 'other';
  locatorValue: string;
  contentCommitment: string; // hex SHA-256 of ciphertext
  encryptionProfile: 'encrypted_envelope';
}

export interface RecordMeta {
  recordId: string;       // hex32 — matches on-chain BytesN<32>
  owner: string;          // patient pseudonym (Stellar address)
  tier: ClinicalHistoryTier;
  category: RecordCategory;
  sensitive: boolean;
  locator: RecordLocator;
  commitment: string;     // hex32
}

// packages/domain/src/access.ts
export type GrantType = 'normal' | 'break_glass' | 'tokenless_fallback';

export interface AccessGrant {
  grantId: string;        // hex32
  record: string;         // recordId hex32
  grantee: string;        // Stellar address
  grantType: GrantType;
  purpose: string;
  scopeCategory: RecordCategory;
  revealAt: number;       // unix seconds (0 for normal grants)
  expiresAt: number;      // unix seconds
  revoked: boolean;
  vetoed: boolean;
}

export interface Capability {
  grantId: string;
  locator: RecordLocator;
  commitment: string;
  // NOTE: Capability contains NO secret material. KMS releases keys separately.
}

export interface PresenceProof {
  tokenPubkey: string;    // hex32 ed25519 public key
  nonce: string;          // hex32 single-use
  expiresAt: number;
  signature: string;      // hex64 ed25519
}
```

---

### DOM-2 — Release predicate as pure function

**Estimate:** 0.5 day
**Blocked by:** DOM-1

**Acceptance Criteria:**
- `packages/domain/src/predicate.ts` exports `evaluateReleasePredicate(grant: AccessGrant | null, caller: string, nowSeconds: number): PredicateResult`
- `PredicateResult` is a discriminated union: `{ allowed: true }` or `{ allowed: false; reason: PredicateDenyReason }`
- 8 unit tests cover every deny branch: null grant, wrong requester, revoked, vetoed, before `revealAt`, at/after `expiresAt`, and the single allow case
- **This function is the canonical predicate.** KMS gate imports it. E2E conformance tests use it. It must never be reimplemented inline elsewhere.

**Technical Notes:**
```typescript
// packages/domain/src/predicate.ts
export type PredicateDenyReason =
  | 'NO_GRANT'
  | 'WRONG_REQUESTER'
  | 'REVOKED'
  | 'VETOED'
  | 'BEFORE_REVEAL'
  | 'EXPIRED';

export type PredicateResult =
  | { allowed: true }
  | { allowed: false; reason: PredicateDenyReason };

/**
 * The release predicate from docs/claude/kms-lit-integration-spec.md §1.
 * committed grant exists AND grant.grantee == caller
 * AND NOT revoked AND NOT vetoed
 * AND revealAt <= now AND now < expiresAt
 */
export function evaluateReleasePredicate(
  grant: AccessGrant | null,
  caller: string,
  nowSeconds: number,
): PredicateResult { ... }
```

This function is intentionally pure (no I/O). Never import network or SDK code into this file.

---

### DOM-3 — Prescription and supply-chain types

**Estimate:** 1 day
**Blocked by:** DOM-1

**Acceptance Criteria:**
- `packages/domain/src/prescription.ts` exports prescription, reservation, and dispensation types
- `packages/domain/src/supplychain.ts` exports drug product, batch, unit, custody, and cold-chain types
- `packages/domain/src/identity.ts` exports actor, credential, and issuer types
- All types must match the Soroban `contracttype` structs defined in IDB, BKR, RX, SC epics

**Technical Notes:**
```typescript
// packages/domain/src/prescription.ts
export type PrescriptionState =
  | 'issued' | 'reserved' | 'dispensed' | 'closed' | 'expired' | 'cancelled';

export interface Prescription {
  prescriptionId: string;   // hex32 — one-time unlinkable identifier
  patientPseudonym: string;
  drugClass: string;        // public; NOT diagnosis or patient name
  clinicianCredRef: string;
  issuedAt: number;
  expiresAt: number;
  state: PrescriptionState;
  reservationRef?: string;  // hex32 when reserved
}

// The bridge: links private clinical event to public supply-chain demand
export interface ReservationPrivacyRef {
  reservationId: string;    // fresh one-time unlinkable identifier
  drugClassCommitment: string;
}
```

---

## EPIC IDB — Identity Contract (`contracts/identity/`)

**Goal:** On-chain credential registry. Credentials gate every privileged action across all other contracts. This is the trust root — everything that claims an identity is checked here.

---

### IDB-1 — Identity contract types and storage layout

**Estimate:** 1 day
**Blocked by:** INF-4

**Acceptance Criteria:**
- `contracts/identity/src/types.rs` defines `CredentialRef`, `CredentialStatus`, `Role`, `IssuerRecord`
- `contracts/identity/src/storage.rs` defines all `DataKey` variants with storage class annotations
- `contracts/identity/src/errors.rs` defines `IdentityError` enum with every error code
- Contract compiles to WASM

**Technical Notes:**
```rust
// contracts/identity/src/types.rs
#[contracttype] #[derive(Clone, PartialEq)]
pub enum Role {
    Patient, Clinician, Institution, Pharmacy,
    Distributor, Manufacturer, Responder, Admin,
}

#[contracttype] #[derive(Clone, PartialEq)]
pub enum CredentialStatus { Active, Revoked, Expired }

#[contracttype] #[derive(Clone)]
pub struct CredentialRef {
    pub subject: Address,
    pub role: Role,
    pub issuer: Address,
    pub expires_at: u64,
    pub status: CredentialStatus,
}

#[contracttype]
pub enum DataKey {
    Admin,                     // instance — always alive
    Issuer(Address),           // persistent — IssuerRecord
    Credential(BytesN<32>),    // persistent — CredentialRef (keyed by cred_id)
    SubjectCreds(Address),     // persistent — Vec<BytesN<32>> (index by subject)
}
```

Storage class discipline: `Admin` is instance (always alive); `Issuer` and `Credential` are persistent (must survive between infrequent use). No temporary storage in identity — credentials must never self-delete.

---

### IDB-2 — Identity contract implementation and tests

**Estimate:** 2 days
**Blocked by:** IDB-1

**Acceptance Criteria:**
- `register_issuer(env, admin, issuer_address)` — admin-only; emits `IssuerRegistered` event
- `issue_credential(env, issuer, subject, role, expires_at) -> BytesN<32>` — returns `cred_id`; issuer must be registered; emits `CredentialIssued`
- `revoke_credential(env, issuer_or_admin, cred_id)` — marks `status = Revoked`; emits `CredentialRevoked`
- `verify_credential(env, cred_id, expected_subject, expected_role) -> bool` — checks Active status, not expired, subject matches, role matches
- All test cases pass: issue, verify, revoke, verify-after-revoke, expired check, wrong-subject check

**Technical Notes:**
- `verify_credential` is called cross-contract from broker and prescription — keep it O(1) lookup by `cred_id`, no iteration
- Event emit: `env.events().publish((symbol_short!("cred_issue"), issuer.clone()), (cred_id.clone(), subject.clone(), role_code))` where `role_code` is a `u32` discriminant

---

## EPIC BKR — Access Broker Contract (`contracts/access-broker/`)

**Goal:** The policy + audit heart of the system. Read `docs/claude/access-broker-contract-design.md` in full before writing any code here. The bug catalog in that doc's §5 (Holes A–I) describes exactly what must be prevented.

---

### BKR-1 — Broker types, storage layout, and errors

**Estimate:** 1 day
**Blocked by:** INF-4, IDB-1

**Acceptance Criteria:**
- `contracts/access-broker/src/types.rs` matches the structs in `docs/claude/access-broker-contract-design.md`: `Tier`, `GrantType`, `RecordMeta`, `Grant`, `PresenceProof`, `CredentialProof`, `Capability`, `Error`
- `contracts/access-broker/src/storage.rs` defines `DataKey` with explicit storage class for each variant (see Technical Notes)
- Contract compiles to WASM

**Technical Notes:**

Storage class assignments — from the architecture doc's rent strategy (§9):

| DataKey | Class | Rationale |
|---|---|---|
| `Admin` | instance | Always alive, single entry |
| `IssuerRoot` | instance | Always alive |
| `Record(BytesN<32>)` | persistent | Clinical commitments must survive |
| `Grant(BytesN<32>)` for normal grants | persistent | Active consent state |
| `Grant(BytesN<32>)` for break-glass | temporary | Self-cleans after expiry |
| `PatientToken(Address)` | persistent | Must survive for emergency auth |
| `SpentNonce(BytesN<32>)` | temporary | Only needs to outlast `MAX_PRESENCE_WINDOW` |

**Critical rule:** Every security check uses `expires_at` and `reveal_at` fields compared against `env.ledger().timestamp()`, never the storage TTL. An entry's TTL lapsing is not proof it has expired by business rules. This is Hole B from the design doc.

---

### BKR-2 — Record registration and patient token registration

**Estimate:** 1 day
**Blocked by:** BKR-1

**Acceptance Criteria:**
- `register_record(env, owner, record_id, tier, category, sensitive, locator_bytes, commitment)` — owner `require_auth()`; stores `RecordMeta`; emits `RecordRegistered`
- `register_patient_token(env, patient, token_pubkey)` — patient `require_auth()`; stores under `PatientToken(patient)`
- Tests: register a record, retrieve `RecordMeta`, register a token, verify token retrieval

**Technical Notes:**
- `locator_bytes` is `Bytes` (opaque) — the contract never interprets it, only stores and returns it
- `commitment` is `BytesN<32>` — SHA-256 of ciphertext, verified off-chain by the reader
- Emit: `env.events().publish((symbol_short!("rec_reg"), owner.clone()), (record_id.clone(), tier_code, category_code))`

---

### BKR-3 — Normal grant creation (Tier 3)

**Estimate:** 1 day
**Blocked by:** BKR-2, IDB-2

**Acceptance Criteria:**
- `create_normal_grant(env, patient, grantee, record_id, purpose, scope_category, expires_at)` — patient `require_auth()`; verifies record exists and patient is owner; stores `Grant` with `gtype = Normal, revoked = false, reveal_at = 0`; emits `GrantCreated`
- `revoke(env, owner, grant_id)` — owner `require_auth()`; verifies owner matches record's owner; sets `revoked = true`; emits `GrantRevoked`
- Test: create grant, read grant state, revoke, verify revoked state

**Technical Notes:**
- `grant_id` derived as `sha256(grantee_bytes || record_id_bytes || now_bytes)` — deterministic, unique per (grantee, record, time) triple
- `reveal_at = 0` for normal grants — no veto window for patient-initiated consent
- **Do not store grants in a patient-indexed `Vec`** — that is Hole H (metering DoS). Every grant lookup is `DataKey::Grant(grant_id)` — O(1) only.

---

### BKR-4 — `request_access` and the on-chain predicate check

**Estimate:** 2 days
**Blocked by:** BKR-3

**Acceptance Criteria:**
- `request_access(env, requester, record_id, purpose, cred, presence) -> Capability` implements the full design doc §3 flow: (0) require_auth, (1) verify credential, (2) authorize by tier, (3) emit audit event, (4) store/update grant, (5) return non-secret Capability
- **Audit event is emitted at step (3)** — before the Capability is built, so no code path returns a Capability without an audit (Hole I)
- Return type `Capability { grant_id, locator, commitment }` contains NO secret material
- Simulation of `request_access` (without submitting the transaction) does NOT commit a grant and does NOT emit an event — verified by a test that calls in simulation mode and confirms no grant entry exists
- All `Error` variants have tests triggering them

**Technical Notes — Bug Catalog (every line must be reviewed against these before merge):**
- **Hole A (simulation scrape):** Capability return value has no secret. KMS only releases against committed on-chain state.
- **Hole B (TTL vs. expiry):** `if now >= g.expires_at { panic_with_error!(&env, Error::GrantExpired) }` — always check the field.
- **Hole C (bearer capability):** KMS re-reads state on every call — enforced in KMS epic, but the non-secret return makes it enforceable.
- **Hole D (unbound presence):** `verify_presence` checks registered token pubkey; nonce stored in `SpentNonce`.
- **Hole E (credential not bound to caller):** `if cred.subject != requester { panic_with_error!(&env, Error::CredentialNotForCaller) }`
- **Hole F (sensitive scope):** `if meta.sensitive && g.scope_category != meta.category { panic_with_error! }`
- **Hole I (unaudited branch):** Event emit must precede Capability construction and be reachable by ALL authorization paths.

---

### BKR-5 — Break-glass grant and veto

**Estimate:** 2 days
**Blocked by:** BKR-4

**Acceptance Criteria:**
- Break-glass path in `request_access` for `Tier::EmergencyBundle`: credential must have role `responder` or `clinician`; both presence-proof path and tokenless-fallback path implemented
- `reveal_at = now + window_for(&meta)` where `window_for` returns `0` for critical instant subset (allergies, implants) and `30` (seconds, configurable via instance storage) for the extended bundle
- `veto(env, owner, grant_id)` — owner `require_auth()`; checks `now < grant.reveal_at` else `Error::WindowClosed`; sets `vetoed = true`; emits `GrantVetoed`
- Tokenless fallback emits a `fallback` event with a distinct topic
- Tests: presence path succeeds, nonce replay fails, wrong token fails, veto within window succeeds, veto after window fails

**Technical Notes:**
- Presence signature verification: `env.crypto().ed25519_verify(&p.token_pubkey, &msg, &p.signature)` where `msg = build_presence_msg(&env, &requester, &record_id, &p.nonce, p.expires_at)` — domain-separated: `"hcstellar:presence:v1" || requester_bytes || record_id_bytes || nonce_bytes || expires_at_be_bytes`
- Spent nonce TTL: `env.storage().temporary().extend_ttl(&DataKey::SpentNonce(nonce), MAX_PRESENCE_WINDOW, MAX_PRESENCE_WINDOW)` where `MAX_PRESENCE_WINDOW = 300u32`
- Break-glass grants use temporary storage (self-cleaning) but `expires_at = now + BREAK_GLASS_WINDOW` is stored in the struct as the security clock

---

### BKR-6 — Delayed offline audit submission

**Estimate:** 1 day
**Blocked by:** BKR-5

**Acceptance Criteria:**
- `submit_delayed_audit(env, submitter, audit_payload_hash, device_sig, read_at, card_id)` — verifies device signature over `(domain || card_id || audit_payload_hash || read_at)`; emits `DelayedAuditSubmitted` with `delayed: true`
- Tests: valid submission emits event, bad device signature panics, replay of same `(card_id, read_at)` pair rejected (spent nonce)

**Technical Notes:**
- Device key registered in `DataKey::CardDevice(BytesN<32>)` persistent entry at offline card creation time
- Emit topic: `(symbol_short!("audit_off"), card_id)` — distinct from online audit events for indexer tagging

---

## EPIC KMS — KMS Gate Service (`apps/kms-gate/`)

**Goal:** The key-release service that enforces the predicate against **committed** Stellar state. The epicenter of "stub decentralization, never stub the predicate."

---

### KMS-1 — KMS gate scaffold and Stellar state reader

**Estimate:** 1 day
**Blocked by:** INF-3, DOM-2

**Acceptance Criteria:**
- `apps/kms-gate/src/stellar/BrokerStateReader.ts` fetches a grant entry from committed Stellar ledger state using `getLedgerEntries` — **NOT** `simulateTransaction`
- `BrokerStateReader.readGrant(grantId: string): Promise<AccessGrant | null>` returns null if entry doesn't exist
- A grant that was only simulated (never submitted) returns null

**Technical Notes:**
- Use `@stellar/stellar-sdk` `server.getLedgerEntries(...)` pattern, constructing the ledger key from the `access-broker` contract ID and `DataKey::Grant(grant_id)`
- Add comment at the call site: `// COMMITTED STATE: do not change to simulateTransaction — see docs/claude/kms-lit-integration-spec.md §4`
- `STELLAR_RPC_URL` and `BROKER_CONTRACT_ID` injected via env vars from Docker Compose

---

### KMS-2 — Release predicate evaluator and key store stub

**Estimate:** 1 day
**Blocked by:** KMS-1, DOM-2

**Acceptance Criteria:**
- `apps/kms-gate/src/predicate/ReleasePredicateEvaluator.ts` imports `evaluateReleasePredicate` from `@medichain/domain` — it does **NOT** reimplement the predicate
- `apps/kms-gate/src/keys/LocalKeyStore.ts` is a stub: given a `grantId`, returns a deterministic wrapped AES-256 key (the stub; will be replaced by Lit Protocol in a future phase)
- All 8 deny cases from DOM-2 tests pass against the evaluator in integration

---

### KMS-3 — HTTP API for key release

**Estimate:** 1 day
**Blocked by:** KMS-2

**Acceptance Criteria:**
- `POST /v1/release` accepts `{ grantId, requester, requesterAuth, locator }`
- Returns `{ wrappedKey: string }` on allow, `{ denied: true, reason: string }` on deny
- `requesterAuth` is verified as an Ed25519 signature over `sha256("hcstellar:kms:v1:" + grantId)` using the `requester` public key — prevents replay
- Rate limiting: max 10 release requests per `requester` per minute
- All deny branches return HTTP 403, not 500
- Every request logged with `{ grantId, requester, decision, reason, timestamp }` — this log is the KMS audit trail

---

### KMS-4 — Conformance test suite (predicate truth table)

**Estimate:** 1 day
**Blocked by:** KMS-3

**Acceptance Criteria:**
- `apps/kms-gate/src/test-vectors/conformance.test.ts` has 15+ grant states with expected decisions
- Every row tested against both `evaluateReleasePredicate` (pure function) AND the live KMS HTTP endpoint — they must agree on every row
- CI runs this suite on every PR

**Required Test Vectors:**

| # | Grant State | Expected |
|---|---|---|
| 1 | `grant = null` (not committed) | `NO_GRANT` |
| 2 | `grant.grantee !== caller` | `WRONG_REQUESTER` |
| 3 | `grant.revoked = true` | `REVOKED` |
| 4 | `grant.vetoed = true` | `VETOED` |
| 5 | `now < grant.revealAt` | `BEFORE_REVEAL` |
| 6 | `now = grant.expiresAt` (boundary) | `EXPIRED` |
| 7 | `now > grant.expiresAt` | `EXPIRED` |
| 8 | All conditions met, `revealAt = 0` | `allow` |
| 9 | All conditions met, `now = grant.revealAt` | `allow` |
| 10 | `revoked = true AND vetoed = true` | `REVOKED` (revocation checked first) |
| 11 | Break-glass, veto window open, patient vetoed | `VETOED` |
| 12 | Break-glass, past `revealAt`, not vetoed | `allow` |
| 13 | Normal grant, `revealAt = 0`, not revoked | `allow` |
| 14 | Expired grant that was previously allowed | `EXPIRED` (re-checked every call) |
| 15 | Simulated (never committed) `request_access` | `NO_GRANT` |

---

## EPIC STR — Storage & Crypto (`packages/storage`, `packages/crypto`)

**Goal:** Envelope encryption for clinical payloads, MinIO storage provider, commitment generation.

---

### STR-1 — Storage provider interface and MinIO implementation

**Estimate:** 2 days
**Blocked by:** INF-3, INF-2

**Acceptance Criteria:**
- `packages/storage/src/RecordStorageProvider.ts` defines the interface:
  ```typescript
  interface RecordStorageProvider {
    store(payload: Uint8Array): Promise<RecordLocator>;
    retrieve(locator: RecordLocator): Promise<Uint8Array>;
  }
  ```
- `packages/storage/src/MinioRecordStorageProvider.ts` implements it
- Bucket `medichain-records` auto-created on first use if missing
- `store` returns `RecordLocator` with `locatorType: 's3'` and `contentCommitment` = SHA-256 of stored bytes
- `retrieve` verifies SHA-256 against `locator.contentCommitment` before returning — tampered blobs throw `CommitmentMismatchError`

**Technical Notes:**
- MinIO endpoint: `http://minio:9000` in Docker Compose
- Check Verdaccio cache for `minio` npm client before unlocking npmjs
- Object key: `records/${sha256(payload).hex}` — content-addressed, so duplicate payloads deduplicate

---

### STR-2 — Envelope encryption service

**Estimate:** 2 days
**Blocked by:** STR-1

**Acceptance Criteria:**
- `packages/crypto/src/EnvelopeEncryptionService.ts` implements:
  ```typescript
  interface EnvelopeEncryptionService {
    encrypt(plaintext: Uint8Array): Promise<{ ciphertext: Uint8Array; wrappedKey: string; keyId: string }>;
    decrypt(ciphertext: Uint8Array, wrappedKey: string): Promise<Uint8Array>;
  }
  ```
- AES-256-GCM for payload encryption; per-record random 256-bit DEK
- `packages/crypto/src/CommitmentService.ts` computes `sha256(ciphertext)` and returns hex
- Tests: encrypt → commitment → store → retrieve → verify commitment → decrypt → matches plaintext

**Technical Notes:**
- Use Node's built-in `crypto` module (`createCipheriv('aes-256-gcm', ...)`) — no external crypto library needed
- The `wrappedKey` is `base64(encrypt_with_master_key(DEK))` where master key is at `kms-gate` startup
- This is the stub: in production, a threshold KMS (Lit Protocol) holds the master key; for MVP, `kms-gate` does
- The predicate is still real: `kms-gate` only returns `wrappedKey` after `evaluateReleasePredicate` passes

---

## EPIC IDX — API-Indexer Service (`apps/api-indexer/`)

**Goal:** Indexes Soroban contract events into Postgres, serves read models, orchestrates veto-window notifications.

---

### IDX-1 — Postgres schema and migrations

**Estimate:** 1 day
**Blocked by:** INF-3

**Acceptance Criteria:**
- `apps/api-indexer/src/storage/migrations/001_initial.sql` creates all tables
- Tables: `grants`, `records`, `audit_events`, `prescriptions`, `inventory_units`, `credentials`, `notifications`, `_indexer_state`
- Migration runs automatically on `api-indexer` startup
- All foreign keys defined; indexes on `grants.grantee`, `grants.record_id`, `audit_events.patient_pseudonym`

**Technical Notes:**
```sql
CREATE TABLE grants (
  grant_id       CHAR(64) PRIMARY KEY,
  record_id      CHAR(64) NOT NULL,
  grantee        VARCHAR(56) NOT NULL,
  grant_type     VARCHAR(32) NOT NULL,
  purpose        VARCHAR(64),
  scope_category VARCHAR(64),
  reveal_at      BIGINT NOT NULL,
  expires_at     BIGINT NOT NULL,
  revoked        BOOLEAN NOT NULL DEFAULT FALSE,
  vetoed         BOOLEAN NOT NULL DEFAULT FALSE,
  indexed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_events (
  event_id          BIGSERIAL PRIMARY KEY,
  event_type        VARCHAR(64) NOT NULL,
  tier              VARCHAR(32),
  patient_pseudonym VARCHAR(56),
  reader_ref        VARCHAR(56),
  record_id         CHAR(64),
  grant_id          CHAR(64),
  delayed           BOOLEAN NOT NULL DEFAULT FALSE,
  raw_event         JSONB NOT NULL,
  ledger_sequence   BIGINT NOT NULL,
  event_timestamp   TIMESTAMPTZ NOT NULL
);

CREATE TABLE _indexer_state (
  key   VARCHAR(64) PRIMARY KEY,
  value TEXT NOT NULL
);
```

---

### IDX-2 — Event ingestor (Soroban event poller)

**Estimate:** 2 days
**Blocked by:** IDX-1, BKR-4

**Acceptance Criteria:**
- `apps/api-indexer/src/events/EventIngestor.ts` polls `getEvents` on the Stellar RPC for all 4 contract event streams
- Each event decoded and upserted into the appropriate Postgres table
- Ingestor stores the last processed ledger sequence and resumes from there on restart (no re-processing)
- Events `access`, `revoke`, `veto`, `fallback`, `audit_off`, `cred_issue`, `cred_revoke`, `rec_reg` are all handled

**Technical Notes:**
- Use `SorobanRpc.Server.getEvents({ startLedger, filters: [{ type: 'contract', contractIds: [...] }] })`
- Cursor stored in `_indexer_state` table: `{ key: 'last_ledger', value: '...' }`
- Poll interval: 5 seconds in development; configurable via `EVENT_POLL_INTERVAL_MS` env var

---

### IDX-3 — Veto-window notification workflow

**Estimate:** 1 day
**Blocked by:** IDX-2

**Acceptance Criteria:**
- When a break-glass grant event is indexed with `reveal_at > now`, a notification is scheduled for the patient
- Notification stored in `notifications` Postgres table AND logged — no external email/SMS in MVP
- Notification includes: `grantId`, `grantee` (responder), `revealAt`, `expiresAt`, deep-link to veto action
- After `revealAt` passes without veto, notification `status` set to `'window_closed'`

---

### IDX-4 — REST API routes

**Estimate:** 1 day
**Blocked by:** IDX-1, IDX-2

**Acceptance Criteria:**
- `GET /v1/grants?patient=<address>` — active grants for a patient
- `GET /v1/audit?patient=<address>` — audit events (online + delayed-offline, sorted by timestamp)
- `GET /v1/notifications?patient=<address>` — pending veto alerts
- `GET /v1/records?patient=<address>` — record metadata (no PHI)
- `GET /v1/health` — returns `{ ok: true }`
- All routes return camelCase JSON; no PHI in any response

---

## EPIC WLT — Wallet Integration

**Goal:** Replace `prompt()` with Freighter. Provide a `WalletAdapter` interface so tests can use a mock signer.

---

### WLT-1 — WalletAdapter interface and MockWalletAdapter

**Estimate:** 1 day
**Blocked by:** INF-2

**Acceptance Criteria:**
- `packages/wallet/src/WalletAdapter.ts` defines:
  ```typescript
  interface WalletAdapter {
    getPublicKey(): Promise<string>;
    signTransaction(xdr: string, network: string): Promise<string>;
    isConnected(): Promise<boolean>;
  }
  ```
- `packages/wallet/src/MockWalletAdapter.ts` implements it using a hardcoded test keypair — used by E2E tests
- The current `src/hooks/useWallet.ts` (localStorage-based, no signing) is replaced by `apps/web/src/hooks/useWallet.ts` wrapping a `WalletAdapter`

---

### WLT-2 — Freighter wallet adapter

**Estimate:** 1 day
**Blocked by:** WLT-1

**Acceptance Criteria:**
- `packages/wallet/src/FreighterWalletAdapter.ts` wraps `@stellar/freighter-api`
- `getPublicKey()` calls `freighter.getPublicKey()`
- `signTransaction()` calls `freighter.signTransaction(xdr, { network })`
- If Freighter not installed, `isConnected()` returns `false` and `getPublicKey()` throws `FreighterNotInstalledError`
- The web app's connect button invokes the adapter, not `prompt()`

**Technical Notes:**
- Check Verdaccio cache for `@stellar/freighter-api` first; it may already be cached
- `packages/wallet/src/index.ts` exports factory: `createWalletAdapter(type: 'freighter' | 'mock')`

---

## EPIC T3 — Tier 3: Full Clinical History Flow

**Goal:** End-to-end working Tier 3 flow. First vertical slice that touches every layer.

---

### T3-1 — Store encrypted record (patient side)

**Estimate:** 2 days
**Blocked by:** STR-2, BKR-2, WLT-2

**Acceptance Criteria:**
- `apps/web/src/app/(patient)/store-record/page.tsx` allows a patient to upload a clinical record (JSON)
- Record encrypted via `EnvelopeEncryptionService`, stored in MinIO via `MinioRecordStorageProvider`
- Commitment and locator registered on the broker via `register_record`
- Transaction signed by Freighter
- After submission, patient sees record in dashboard with `commitment` and `tier`

**Technical Notes:**
- `packages/stellar-client/src/AccessBrokerContractClient.ts` wraps `register_record` invocation: takes domain types, serializes to XDR, returns transaction hash
- Migrate existing dashboard from `src/app/dashboard/page.tsx` → `apps/web/src/app/(patient)/dashboard/page.tsx`

---

### T3-2 — Grant access to clinician (patient side)

**Estimate:** 1 day
**Blocked by:** T3-1

**Acceptance Criteria:**
- Patient selects a record, enters clinician Stellar address, sets scope category and expiry, calls `create_normal_grant`
- Grant submitted and confirmed on-chain
- Patient dashboard shows active grant with revoke button
- Revoke calls `revoke(grant_id)` and grant disappears after indexer updates

---

### T3-3 — Clinician reads record through KMS predicate

**Estimate:** 2 days
**Blocked by:** T3-2, KMS-3, IDX-2

**Acceptance Criteria:**
- Clinician calls `request_access(record_id, ...)` — broker returns `Capability { grantId, locator, commitment }`
- Clinician app sends `POST /v1/release` to `kms-gate` with `grantId` and `requesterAuth`
- KMS reads committed Stellar state, evaluates predicate, returns `wrappedKey`
- Clinician app retrieves ciphertext from MinIO, verifies SHA-256 against `commitment`, decrypts
- Clinician sees plaintext record in `apps/web/src/app/(clinician)/record-view/page.tsx`
- If grant is revoked between `request_access` and KMS release, KMS returns `{ denied: true, reason: 'REVOKED' }` and UI shows error

---

## EPIC T2 — Tier 2: Break-Glass + Veto Window

**Goal:** Emergency break-glass flow with conscious-patient veto. The most complex security-critical flow in the MVP.

---

### T2-1 — Tier 2 emergency bundle construction and storage

**Estimate:** 1 day
**Blocked by:** T3-1

**Acceptance Criteria:**
- Patient creates a Tier 2 emergency bundle from the patient dashboard — selects which records contribute
- Bundle separately encrypted with its own DEK (distinct from Tier 3 record keys)
- Commitment and locator registered on broker with `tier = EmergencyBundle`
- Bundle schema matches `docs/clinical-history-tiers.md` Tier 2 data format

---

### T2-2 — Break-glass access request (responder side)

**Estimate:** 2 days
**Blocked by:** T2-1, BKR-5, WLT-2

**Acceptance Criteria:**
- `apps/web/src/app/(responder)/emergency-access/page.tsx` allows a credentialed responder to initiate break-glass
- Responder provides: patient lookup (address or card scan), credential proof, presence proof (if available), reason code
- `request_access` called with `tier = EmergencyBundle`; broker emits audit event, creates grant with `reveal_at = now + 30`
- UI shows countdown to `revealAt` and "pending veto window" state
- After `revealAt` passes without veto, UI auto-triggers KMS release
- KMS release and read follow T3-3 pattern

---

### T2-3 — Conscious-patient veto

**Estimate:** 1 day
**Blocked by:** T2-2, IDX-3

**Acceptance Criteria:**
- Patient's app (via `GET /v1/notifications`) shows a live veto alert: "Emergency access requested by [responder]. Expires in [countdown]. Tap to veto."
- Patient calls `veto(grant_id)` before `revealAt` — signed by Freighter
- After veto confirmed on-chain and indexed, responder's UI shows "Access vetoed by patient"
- KMS release attempt for vetoed grant returns `{ denied: true, reason: 'VETOED' }`
- Test: veto at `revealAt - 5s` → denied; veto attempt at `revealAt + 1s` → `WindowClosed` error from contract

---

### T2-4 — Tokenless fallback path

**Estimate:** 1 day
**Blocked by:** T2-2

**Acceptance Criteria:**
- When no presence proof provided, broker routes to tokenless fallback in `authorize_emergency`
- Fallback requires dual co-sign: primary responder's credential + second clinician or institution credential
- UI: after primary submits, a second approver must confirm before grant is created
- Fallback grants emit the `fallback` audit topic; indexer tags them `grant_type: 'tokenless_fallback'`
- Fallback only authorizes vital subset (records marked `sensitive: false` in critical category)

---

## EPIC T1 — Tier 1: Offline Emergency Card

**Goal:** A self-verifying signed payload the patient carries. Offline read with deferred audit.

---

### T1-1 — Offline card generation and signing

**Estimate:** 2 days
**Blocked by:** STR-2, BKR-2

**Acceptance Criteria:**
- Patient creates offline emergency card from the dashboard
- Card payload matches `docs/clinical-history-tiers.md` Tier 1 schema: allergies, critical meds, major conditions, implants, directive flag, emergency contacts, pointer to Tier 2 bundle
- Card payload signed by patient's key (Ed25519 via Freighter) — signature covers all non-signature fields
- Card encoded as QR code and NFC NDEF record URI; available for download/print
- `offlineAudit.budgetId` registered on-chain (`DataKey::CardDevice`) with `remainingReads = 50`

**Technical Notes:**
- Card payload is JSON, canonically serialized (sorted keys) before signing — required for deterministic signature verification
- `onlineEmergencyPointer.locator` points to Tier 2 bundle's MinIO location
- Check Verdaccio cache for `qrcode` npm library

---

### T1-2 — Offline card reader and deferred audit submission

**Estimate:** 2 days
**Blocked by:** T1-1, BKR-6

**Acceptance Criteria:**
- `apps/web/src/app/(responder)/offline-card/page.tsx` accepts QR scan or file paste of card JSON
- Responder app verifies card signature using `token_pubkey` from the card payload
- On verification success, displays card contents (allergies, meds, conditions)
- Creates local deferred audit record stored in localStorage: `{ cardId, readAtDeviceTime, responderRef, deviceSignature }`
- When network returns, responder app calls `submit_delayed_audit` on broker contract
- Submitted delayed audit shows in patient's audit log with `delayed: true`

---

## EPIC RX — Prescription Contract (`contracts/prescription/`)

**Goal:** The bridge object. Stateful prescription from issuance through dispensation with patient active co-signature.

---

### RX-1 — Prescription contract types and storage

**Estimate:** 1 day
**Blocked by:** INF-4, IDB-1

**Acceptance Criteria:**
- `contracts/prescription/src/types.rs` defines `PrescriptionState`, `Prescription`, `Reservation`, `DispensationReceipt`
- `contracts/prescription/src/storage.rs` defines: `Prescription(BytesN<32>)` as persistent, `Reservation(BytesN<32>)` as temporary (escrow auto-expires)
- Contract compiles to WASM

**Technical Notes:**
```rust
#[contracttype] #[derive(Clone, PartialEq)]
pub enum PrescriptionState { Issued, Reserved, Dispensed, Closed, Expired, Cancelled }

#[contracttype] #[derive(Clone)]
pub struct Prescription {
    pub prescription_id: BytesN<32>,
    pub patient_pseudonym: Address,
    pub drug_class: Symbol,         // public — NOT diagnosis, NOT patient name
    pub clinician_cred_ref: BytesN<32>,
    pub issued_at: u64,
    pub expires_at: u64,
    pub state: PrescriptionState,
    pub reservation_ref: Option<BytesN<32>>,
}
```

`prescription_id` is derived as `sha256(patient_pseudonym || nonce || issued_at)` — unlinkable across prescriptions for the same patient in the public supply graph.

---

### RX-2 — Prescription issuance and reservation

**Estimate:** 2 days
**Blocked by:** RX-1, IDB-2

**Acceptance Criteria:**
- `issue_prescription(env, clinician, patient_pseudonym, drug_class, expires_at) -> BytesN<32>` — clinician `require_auth()`; credential check via cross-contract call to identity; emits `PrescriptionIssued`
- `reserve(env, patient, prescription_id, pharmacy_address, unit_id) -> BytesN<32>` — patient `require_auth()`; cross-contract call to supplychain to lock unit; emits `PrescriptionReserved`; state → `Reserved`
- Tests: issue, reserve, attempt double-reserve (fails), cancel reservation

**Technical Notes:**
- Cross-contract call pattern: `env.invoke_contract(&supply_chain_id, &symbol_short!("reserve_unit"), soroban_sdk::vec![&env, unit_id, prescription_id])`
- Supply chain contract ID stored in instance storage as `DataKey::SupplychainId`
- `reservation_ref` is `sha256(prescription_id || unit_id || patient_pseudonym)` — unlinkable privacy ref

---

### RX-3 — Dispensation with patient active co-signature and receipt writeback

**Estimate:** 2 days
**Blocked by:** RX-2, BKR-3

**Acceptance Criteria:**
- `dispense(env, pharmacy, patient, prescription_id, dispensation_receipt_commitment)` — requires BOTH `pharmacy.require_auth()` AND `patient.require_auth()` in the same transaction — this is the active co-signature anti-ghost-dispense rule
- Calls supplychain `dispense_unit` cross-contract
- Calls access broker `register_record` cross-contract to commit dispensation receipt back to patient's Tier 3 record
- State → `Dispensed`; emits `PrescriptionDispensed`
- **Test: dispense with only pharmacy sig fails. This is the most important test in the RX epic.**

**Technical Notes:**
- In Soroban, requiring two auth contexts: both `pharmacy.require_auth()` and `patient.require_auth()` in the same function — Soroban validates both in the auth DAG
- `dispensation_receipt_commitment` is `BytesN<32>` — SHA-256 of the encrypted dispensation JSON stored in MinIO by the pharmacy app before calling dispense

---

## EPIC SC — Supply-Chain Contract (`contracts/supplychain/`)

**Goal:** Drug provenance, custody transfer, cold-chain oracle, and inventory reservation.

---

### SC-1 — Supply-chain types and storage

**Estimate:** 1 day
**Blocked by:** INF-4

**Acceptance Criteria:**
- `contracts/supplychain/src/types.rs` defines: `DrugProduct`, `DrugBatch`, `BatchStatus`, `InventoryUnit`, `UnitStatus`, `CustodyRecord`, `ColdChainStatus`, `OpposingInterestAttestation`
- `BatchStatus` includes `Available, Reserved, Dispensed, Quarantined, Expired`
- Storage: `Batch(BytesN<32>)` persistent, `Unit(BytesN<32>)` persistent, `BatchUnits(BytesN<32>)` persistent (manifest), `ColdChainLog(BytesN<32>)` temporary (recent excursions only)
- Contract compiles to WASM

---

### SC-2 — Batch registration and unit serialization

**Estimate:** 1 day
**Blocked by:** SC-1, IDB-2

**Acceptance Criteria:**
- `register_batch(env, manufacturer, gtin, lot_number, expiry_date, unit_count) -> BytesN<32>` — manufacturer credential required; emits `BatchRegistered`
- `serialize_unit(env, manufacturer, batch_id, serial_number) -> BytesN<32>` — creates `InventoryUnit` under `DataKey::Unit`; emits `UnitSerialized`
- Tests: register batch, serialize units, query unit status

---

### SC-3 — Custody transfer and cold-chain oracle

**Estimate:** 2 days
**Blocked by:** SC-2

**Acceptance Criteria:**
- `transfer_custody(env, from, to, unit_id, opposing_attester_sig)` — both `from.require_auth()` and the opposing attester's signature verified via `env.crypto().ed25519_verify()`; emits `CustodyTransferred`
- `record_cold_chain(env, oracle, batch_id, temperature_c, timestamp)` — oracle address pre-registered in instance storage; if temperature outside range, calls `quarantine_batch`
- `quarantine_batch(env, batch_id)` — sets all units to `Quarantined`; reservation on quarantined units fails
- Tests: transfer custody, cold chain excursion triggers quarantine, reservation on quarantined batch fails

**Technical Notes:**
- The `opposing_attester_sig` is an Ed25519 signature verified against the attester's registered public key — the attester must have opposing interest (pharmacy, regulatory body), registered separately from the custody chain. This is the threat-model requirement from `docs/claude/stellar-integrated-health-supply-plan_final.md` §5.4 and §8.

---

### SC-4 — Inventory reservation and dispense

**Estimate:** 1 day
**Blocked by:** SC-3

**Acceptance Criteria:**
- `reserve_unit(env, prescription_contract, unit_id, reservation_ref)` — only callable by the prescription contract; sets `UnitStatus::Reserved`; emits `UnitReserved`
- `dispense_unit(env, prescription_contract, unit_id)` — only callable by prescription contract; sets `UnitStatus::Dispensed`; emits `UnitDispensed`
- `release_reservation(env, unit_id)` — called by prescription contract on cancel/expire; sets unit back to `Available`
- Tests: reserve, dispense, reserve-then-release, attempt-reserve-on-quarantined

---

## EPIC WEB — Web App Integration

**Goal:** Wire all flows into the Next.js UI for all five roles: patient, clinician, pharmacy, responder, admin.

---

### WEB-1 — Role-based routing and layout

**Estimate:** 1 day
**Blocked by:** WLT-2, INF-1

**Acceptance Criteria:**
- `apps/web/src/app/` has route groups: `(patient)`, `(clinician)`, `(pharmacy)`, `(responder)`, `(admin)`
- Each group has its own layout with role-appropriate navigation
- Wallet connection gate: all role pages redirect to `/connect` if no wallet connected
- Existing pages (`src/app/dashboard`, `src/app/doctor`) migrated into appropriate role groups

---

### WEB-2 — Patient dashboard (records, grants, audit, veto alerts)

**Estimate:** 2 days
**Blocked by:** WEB-1, T3-1, T3-2, IDX-4

**Acceptance Criteria:**
- Patient dashboard shows: active records (with tier badges), active grants, audit event log, pending veto alerts
- Veto alerts show countdown timer until `revealAt`; veto button calls `veto(grant_id)` and is disabled after `revealAt`
- Revoking a grant calls `revoke(grant_id)` via Freighter
- All data fetched from `api-indexer` REST API (no direct contract calls from the dashboard)

---

### WEB-3 — Clinician workflow (request access, view record, write record, issue prescription)

**Estimate:** 2 days
**Blocked by:** T3-3, RX-2, WEB-1

**Acceptance Criteria:**
- Clinician looks up patient by address, requests access to record
- After KMS release, record displays with commitment verification badge ("Verified against on-chain commitment")
- Clinician writes new record entry (encrypted, committed to broker)
- Clinician issues prescription (drug class, expiry) — calls `issue_prescription`
- All actions require a valid clinician credential (shown in UI; contract enforces)

---

### WEB-4 — Pharmacy workflow (view reservations, dispense)

**Estimate:** 1 day
**Blocked by:** RX-3, WEB-1

**Acceptance Criteria:**
- Pharmacy sees incoming reservations from the indexer
- Dispense flow: pharmacy confirms, patient scans QR/NFC or enters confirmation code for co-signature, both sigs submitted in the same transaction
- After dispense, encrypted receipt commitment written back to patient's record
- Quarantined inventory units shown with warning badge and cannot be selected for dispense

---

### WEB-5 — Responder emergency access workflow

**Estimate:** 1 day
**Blocked by:** T2-2, T2-4, T1-2, WEB-1

**Acceptance Criteria:**
- Responder can scan a Tier 1 QR card (offline path) or initiate Tier 2 break-glass (online path)
- Offline path: verifies card signature, displays contents, queues deferred audit
- Online path: initiates break-glass, shows veto-window countdown, auto-triggers KMS release after window
- Tokenless fallback: if no presence proof available, prompts second clinician to co-sign

---

## EPIC E2E — End-to-End Tests

**Goal:** Automated conformance and security tests running against the full Docker-composed stack.

---

### E2E-1 — Test infrastructure and mock wallet

**Estimate:** 1 day
**Blocked by:** INF-3, WLT-1

**Acceptance Criteria:**
- Playwright configured in `e2e/` with `playwright.config.ts` pointing at `http://web:3000`
- `MockWalletAdapter` injected into test browser context via test-only env var `NEXT_PUBLIC_WALLET_ADAPTER=mock`
- Seed data (patient, clinician, responder, pharmacy) automatically loaded before each test suite
- `e2e/helpers/stellar.ts` provides `waitForTransaction(hash)` and `getGrantState(grantId)` helpers

---

### E2E-2 — Tier 3 happy path and revocation test

**Estimate:** 1 day
**Blocked by:** E2E-1, T3-3

**Acceptance Criteria:**
- Test: patient stores record → grants clinician → clinician reads → verify commitment → record displayed
- Test: patient stores record → grants clinician → patient revokes → clinician KMS release attempt → returns `REVOKED` → UI shows error
- Test: grant expires naturally (short `expiresAt`) → KMS returns `EXPIRED`

---

### E2E-3 — Break-glass and veto conformance tests

**Estimate:** 1 day
**Blocked by:** E2E-2, T2-3

**Acceptance Criteria:**
- Test: responder opens break-glass → patient vetoes within window → KMS returns `VETOED`
- Test: responder opens break-glass → no veto → after `revealAt` → KMS returns key → record displayed
- Test: break-glass with tokenless fallback → requires second co-sign → after dual co-sign → access granted

---

### E2E-4 — Prescription bridge end-to-end test

**Estimate:** 2 days
**Blocked by:** E2E-3, RX-3, SC-4

**Acceptance Criteria:**
- Full loop: clinician writes diagnosis → issues prescription → patient selects pharmacy → pharmacy dispenses with patient co-sign → dispensation receipt appears in patient's Tier 3 record
- Test: pharmacy-only dispense (no patient sig) → transaction fails
- Test: reserve against quarantined batch → reservation fails with `BatchQuarantined` error

---

### E2E-5 — KMS predicate security conformance test

**Estimate:** 1 day
**Blocked by:** E2E-4, KMS-4

**Acceptance Criteria:**
- The KMS-4 conformance test vector table is executed end-to-end: each vector creates the corresponding Stellar ledger state, then calls the KMS HTTP endpoint, and verifies response matches expected decision
- Test confirms a simulated (never-submitted) `request_access` produces no usable key release — this is the simulation-scrape defense test
- All 15 test vectors pass

---

## Dependency Graph

```
INF-1 → INF-2 → DOM-1 → DOM-2
INF-1 → INF-3 → INF-5
INF-1 → INF-4 → IDB-1 → IDB-2
INF-4 → BKR-1 → BKR-2 → BKR-3 → BKR-4 → BKR-5 → BKR-6
DOM-2 + INF-3 → KMS-1 → KMS-2 → KMS-3 → KMS-4
INF-3 + INF-2 → STR-1 → STR-2
INF-3 + BKR-4 → IDX-1 → IDX-2 → IDX-3 → IDX-4
INF-2 → WLT-1 → WLT-2
STR-2 + BKR-2 + WLT-2 → T3-1 → T3-2 → T3-3
T3-1 + BKR-5 → T2-1 → T2-2 → T2-3 / T2-4
T2-1 → T1-1 → T1-2
IDB-2 + INF-4 → RX-1 → RX-2 → RX-3
SC-1 → SC-2 → SC-3 → SC-4
WLT-2 + INF-1 → WEB-1 → WEB-2...WEB-5
INF-3 + WLT-1 → E2E-1 → E2E-2 → E2E-3 → E2E-4 → E2E-5
```

**Critical path gates:**
1. **INF-1** (monorepo) and **INF-4** (Cargo workspace) — must be done before any developer can start productive parallel work
2. **BKR-4** (`request_access` + on-chain predicate) and **KMS-3** (HTTP key release) — nothing in Tier 3, Tier 2, or the prescription bridge is testable end-to-end until these two tasks pass

---

## Cross-Cutting Implementation Rules

These apply to every task. Violations block merge.

**1. PHI never on-chain.** Any string that could identify a patient (name, DOB, diagnosis text, medication name in a patient-specific context) must not appear in any contract argument, return value, or event. If a reviewer needs to ask "is this PHI?", the answer is yes and it must move off-chain.

**2. Stub decentralization, never stub the predicate.** Any code path that evaluates the release predicate must call `evaluateReleasePredicate` from `packages/domain/src/predicate.ts`. No inline predicate reimplementations. The KMS key store can be a local single-service stub. The predicate cannot be stubbed. Reviewed at the PR level.

**3. Audit before capability.** In the broker contract, the `env.events().publish(...)` call for the access audit event must appear before the `Capability { ... }` is constructed in `request_access`. Audit emit moved below the return = critical bug (Hole I).

**4. Business expiry, not TTL.** Every access control check in Rust must compare against `expires_at` and `reveal_at` fields from the struct, not whether a storage entry exists.

**5. All grant lookups are O(1).** No contract function may iterate a `Vec` of grants on a hot path. Every lookup is `DataKey::Grant(grant_id)`. If a feature seems to require iteration, redesign the storage layout.

**6. Committed state only in KMS.** `BrokerStateReader` in `kms-gate` must call `getLedgerEntries` on the live ledger, never `simulateTransaction`. Annotate the call site: `// COMMITTED STATE: do not change to simulateTransaction — see docs/claude/kms-lit-integration-spec.md §4`

---

## Critical Files for Implementation

| File | Epic | Why Critical |
|------|------|--------------|
| `contracts/access-broker/src/lib.rs` | BKR-4, BKR-5 | All security-critical decisions converge here |
| `packages/domain/src/predicate.ts` | DOM-2 | Canonical release predicate — source of truth |
| `apps/kms-gate/src/predicate/ReleasePredicateEvaluator.ts` | KMS-2 | Must import from `@medichain/domain`, never reimplement |
| `docker-compose.yml` | INF-3 | Full Docker stack — no integration work until all services run |
| `contracts/prescription/src/lib.rs` | RX-3 | `dispense` dual-auth is the anti-ghost-dispense control |

---

## Verification (End-to-End)

The MVP is done when this scenario runs fully automated in `E2E-5`:

1. Patient registers, stores Tier 3 record, creates Tier 2 emergency bundle, generates Tier 1 offline card
2. Patient grants clinician access to the Tier 3 record
3. Clinician requests access → KMS releases key → clinician reads record → commitment verified
4. Clinician issues prescription → patient reserves at pharmacy
5. Patient arrives at pharmacy → pharmacy initiates dispense → patient co-signs → unit dispensed → receipt appears in patient Tier 3 record
6. Responder initiates break-glass → patient vetoes within window → KMS returns VETOED
7. Second responder initiates break-glass → no veto → after revealAt → KMS releases key → responder reads Tier 2 bundle
8. Responder scans Tier 1 offline QR card → verifies signature → displays critical info → deferred audit queues → submits on reconnect
9. All 15 KMS predicate conformance vectors pass

A regulator watching the chain sees: prescription state, batch provenance, dispensation events, audit events. They see nothing that identifies the patient or the diagnosis.
