#!/usr/bin/env bash
# Creates all MediChain MVP tasks in chainlink from IMPLEMENTATION-TASKS.md
set -e
CL="chainlink -q"

echo "=== Creating milestones ==="
M_INF=$(chainlink milestone create -q "INF — Infrastructure & Monorepo" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo 1)
M_DOM=$($CL milestone create "DOM — Domain Package" | grep -o '[0-9]*' | head -1)
M_IDB=$($CL milestone create "IDB — Identity Contract" | grep -o '[0-9]*' | head -1)
M_BKR=$($CL milestone create "BKR — Access Broker Contract" | grep -o '[0-9]*' | head -1)
M_KMS=$($CL milestone create "KMS — KMS Gate Service" | grep -o '[0-9]*' | head -1)
M_STR=$($CL milestone create "STR — Storage & Crypto" | grep -o '[0-9]*' | head -1)
M_IDX=$($CL milestone create "IDX — API-Indexer Service" | grep -o '[0-9]*' | head -1)
M_WLT=$($CL milestone create "WLT — Wallet Integration" | grep -o '[0-9]*' | head -1)
M_T3=$($CL milestone create "T3 — Tier 3 Full History" | grep -o '[0-9]*' | head -1)
M_T2=$($CL milestone create "T2 — Tier 2 Break-Glass" | grep -o '[0-9]*' | head -1)
M_T1=$($CL milestone create "T1 — Tier 1 Offline Card" | grep -o '[0-9]*' | head -1)
M_RX=$($CL milestone create "RX — Prescription Contract" | grep -o '[0-9]*' | head -1)
M_SC=$($CL milestone create "SC — Supply-Chain Contract" | grep -o '[0-9]*' | head -1)
M_WEB=$($CL milestone create "WEB — Web App Integration" | grep -o '[0-9]*' | head -1)
M_E2E=$($CL milestone create "E2E — End-to-End Tests" | grep -o '[0-9]*' | head -1)
echo "Milestones: INF=$M_INF DOM=$M_DOM IDB=$M_IDB BKR=$M_BKR KMS=$M_KMS STR=$M_STR IDX=$M_IDX WLT=$M_WLT T3=$M_T3 T2=$M_T2 T1=$M_T1 RX=$M_RX SC=$M_SC WEB=$M_WEB E2E=$M_E2E"

echo ""
echo "=== EPIC INF — Infrastructure & Monorepo ==="

INF1=$($CL issue create \
  -p high \
  -l "infra" \
  -d "Convert root to pnpm monorepo with workspaces.

Acceptance Criteria:
- pnpm-workspace.yaml defines components/{web,api-indexer,kms-gate}, components/packages/*, e2e
- pnpm install from root resolves all packages through Verdaccio
- cd components/web && pnpm build succeeds for the web app
- TypeScript project references wired so components/packages/* can be imported in components/{web,api-indexer,kms-gate} without path hacks
- TypeScript configs are component-owned; each package has its own tsconfig.json with composite: true

Technical Notes:
- Move src/ → components/web/src/; update next.config.js, tailwind.config.js, postcss.config.js
- components/web/.npmrc points to http://localhost:4873/ — confirm it resolves through Verdaccio after restructure
- components/web/tsconfig.json stays self-contained so the web component can become a submodule

Estimate: 2 days" \
  "INF-1 — Convert root to pnpm monorepo with workspaces")
echo "INF-1 = $INF1"
chainlink milestone add $M_INF $INF1 -q 2>/dev/null || true

INF2=$($CL issue create \
  -p high \
  -l "infra" \
  -d "Scaffold package and app directory skeletons.

Acceptance Criteria:
- All directories exist with valid package.json + tsconfig.json:
  - components/packages/domain, components/packages/crypto, components/packages/storage, components/packages/stellar-client, components/packages/wallet, components/packages/test-fixtures
  - components/web, components/api-indexer, components/kms-gate
  - e2e/
- Each package exports at least one placeholder symbol so TypeScript can resolve imports
- cd components/web && pnpm typecheck passes with zero errors for the web package and referenced shared packages

Technical Notes:
- Package scope: @medichain/domain, @medichain/crypto, etc.
- Each package.json: main/types/scripts with build and typecheck scripts
- components/packages/domain/src/index.ts exports DOMAIN_VERSION = '0.1.0' as smoke-test placeholder

Estimate: 1 day" \
  "INF-2 — Scaffold package and app skeletons")
echo "INF-2 = $INF2"
chainlink milestone add $M_INF $INF2 -q 2>/dev/null || true
chainlink issue block $INF2 $INF1 -q 2>/dev/null || true

INF3=$($CL issue create \
  -p high \
  -l "infra" -l "docker" \
  -d "Expand Docker Compose: postgres, minio, stellar-local, api-indexer, kms-gate.

Acceptance Criteria:
- docker compose -f e2e/docker-compose.yml up starts all 8 services: verdaccio, web, api-indexer, kms-gate, postgres, minio, stellar-local, contract-runner
- Postgres healthcheck passes (pg_isready)
- MinIO healthcheck passes (HTTP 200 on /minio/health/live)
- stellar-local starts the Quickstart image and exposes Soroban RPC on port 8000
- contract-runner is a short-lived container that deploys contracts on startup then exits 0
- None of the new services reach registry.npmjs.org directly

Technical Notes:
- stellar-local: stellar/quickstart:testing image, --enable-soroban-rpc flag
- Postgres: postgres:16-alpine, POSTGRES_DB=medichain POSTGRES_USER=medichain POSTGRES_PASSWORD=medichain
- MinIO: minio/minio:latest, server /data --console-address ':9001', MINIO_ROOT_USER=medichain
- Add components/api-indexer/Dockerfile and components/kms-gate/Dockerfile following components/web/Dockerfile pattern
- STELLAR_RPC_URL=http://stellar-local:8000 injected into api-indexer and kms-gate

Estimate: 2 days" \
  "INF-3 — Expand Docker Compose with all services")
echo "INF-3 = $INF3"
chainlink milestone add $M_INF $INF3 -q 2>/dev/null || true
chainlink issue block $INF3 $INF1 -q 2>/dev/null || true

INF4=$($CL issue create \
  -p high \
  -l "infra" -l "contracts" \
  -d "Set up Cargo workspace for all 5 Soroban contracts.

Acceptance Criteria:
- components/contracts/Cargo.toml is a workspace manifest listing all 5 contracts as members
- cargo build --release --target wasm32-unknown-unknown from components/contracts/ succeeds for all contracts
- Each new contract directory contains src/lib.rs, src/types.rs, src/storage.rs, src/events.rs, src/errors.rs, src/test.rs
- All 5 contracts compile to .wasm without warnings

Technical Notes:
- New contracts: identity/, access-broker/, prescription/, supplychain/, incentive/
- Workspace soroban-sdk = '22.0'; each contract pins { workspace = true }
- medical-record contract remains compilable but is deprecated; do not extend it
- Cargo.toml workspace resolver = '2'

Estimate: 1 day" \
  "INF-4 — Soroban contract workspace (Cargo workspace)")
echo "INF-4 = $INF4"
chainlink milestone add $M_INF $INF4 -q 2>/dev/null || true
chainlink issue block $INF4 $INF1 -q 2>/dev/null || true

INF5=$($CL issue create \
  -p medium \
  -l "infra" -l "contracts" \
  -d "Contract deployment script and seed data runner.

Acceptance Criteria:
- contract-runner container deploys all 5 contracts to stellar-local on startup
- Contract IDs written to shared volume at /shared/contract-ids.json
- Seed script creates: 1 admin, 2 patients, 2 clinicians, 1 pharmacy, 1 responder — all funded
- api-indexer reads contract IDs from the shared volume at startup and logs them

Technical Notes:
- Script at scripts/deploy-contracts.sh using soroban contract deploy CLI from stellar-dev/
- contract-ids.json shape: { identity, accessBroker, prescription, supplychain, incentive }
- Seed data in components/api-indexer/src/seed/seed.ts — runs only when NODE_ENV=development and DB is empty

Estimate: 1 day" \
  "INF-5 — Contract deployment script and seed data runner")
echo "INF-5 = $INF5"
chainlink milestone add $M_INF $INF5 -q 2>/dev/null || true
chainlink issue block $INF5 $INF3 -q 2>/dev/null || true
chainlink issue block $INF5 $INF4 -q 2>/dev/null || true

echo ""
echo "=== EPIC DOM — Domain Package ==="

DOM1=$($CL issue create \
  -p high \
  -l "domain" -l "typescript" \
  -d "Core clinical and access types for components/packages/domain.

Acceptance Criteria:
- components/packages/domain/src/clinical-history.ts exports ClinicalHistoryTier, RecordCategory, RecordLocator, RecordMeta
- components/packages/domain/src/access.ts exports AccessGrant, Capability, PresenceProof, CredentialProof, GrantType
- components/packages/domain/src/audit.ts exports online and delayed-offline audit event types
- Zero any-casts; strict TypeScript

Technical Notes:
- ClinicalHistoryTier: 'offline_emergency_card' | 'online_emergency_bundle' | 'full_clinical_history'
- AccessGrant: { grantId, record, grantee, grantType, purpose, scopeCategory, revealAt, expiresAt, revoked, vetoed }
- Capability contains NO secret material — broker returns pointer only, KMS releases keys separately
- PresenceProof: { tokenPubkey, nonce, expiresAt, signature } — all hex-encoded

Estimate: 1 day" \
  "DOM-1 — Core clinical and access types")
echo "DOM-1 = $DOM1"
chainlink milestone add $M_DOM $DOM1 -q 2>/dev/null || true
chainlink issue block $DOM1 $INF2 -q 2>/dev/null || true

DOM2=$($CL issue create \
  -p critical \
  -l "domain" -l "security" \
  -d "Release predicate as pure function — the canonical implementation all layers share.

Acceptance Criteria:
- components/packages/domain/src/predicate.ts exports evaluateReleasePredicate(grant, caller, nowSeconds): PredicateResult
- PredicateResult: { allowed: true } | { allowed: false; reason: PredicateDenyReason }
- PredicateDenyReason: NO_GRANT | WRONG_REQUESTER | REVOKED | VETOED | BEFORE_REVEAL | EXPIRED
- 8 unit tests cover every deny branch and the allow case
- This function MUST NEVER be reimplemented inline elsewhere — KMS gate imports it

The predicate: committed grant exists AND grant.grantee == caller AND NOT revoked AND NOT vetoed AND revealAt <= now AND now < expiresAt

Technical Notes:
- Intentionally pure (no I/O). Never import network or SDK code into this file.
- KMS gate imports from @medichain/domain — enforced at PR review

Estimate: 0.5 day" \
  "DOM-2 — Release predicate as pure function")
echo "DOM-2 = $DOM2"
chainlink milestone add $M_DOM $DOM2 -q 2>/dev/null || true
chainlink issue block $DOM2 $DOM1 -q 2>/dev/null || true

DOM3=$($CL issue create \
  -p medium \
  -l "domain" -l "typescript" \
  -d "Prescription and supply-chain types for components/packages/domain.

Acceptance Criteria:
- components/packages/domain/src/prescription.ts exports PrescriptionState, Prescription, ReservationPrivacyRef, DispensationReceipt
- components/packages/domain/src/supplychain.ts exports DrugProduct, DrugBatch, BatchStatus, InventoryUnit, UnitStatus, CustodyRecord
- components/packages/domain/src/identity.ts exports Role, CredentialRef, CredentialStatus, IssuerRecord
- All types must match the Soroban contracttype structs in IDB, BKR, RX, SC epics

Technical Notes:
- PrescriptionState: 'issued' | 'reserved' | 'dispensed' | 'closed' | 'expired' | 'cancelled'
- prescription_id is a one-time unlinkable identifier — NOT stable patient-drug edge
- ReservationPrivacyRef links private clinical event to public supply-chain demand without revealing patient identity

Estimate: 1 day" \
  "DOM-3 — Prescription and supply-chain types")
echo "DOM-3 = $DOM3"
chainlink milestone add $M_DOM $DOM3 -q 2>/dev/null || true
chainlink issue block $DOM3 $DOM1 -q 2>/dev/null || true

echo ""
echo "=== EPIC IDB — Identity Contract ==="

IDB1=$($CL issue create \
  -p high \
  -l "contracts" -l "identity" \
  -d "Identity contract types and storage layout.

Acceptance Criteria:
- components/contracts/identity/src/types.rs defines Role, CredentialStatus, CredentialRef, IssuerRecord
- components/contracts/identity/src/storage.rs defines DataKey with storage class annotations
- components/contracts/identity/src/errors.rs defines IdentityError with every error code
- Contract compiles to WASM

Technical Notes:
- Role enum: Patient, Clinician, Institution, Pharmacy, Distributor, Manufacturer, Responder, Admin
- Storage discipline: Admin = instance (always alive); Issuer = persistent; Credential = persistent; SubjectCreds = persistent
- NO temporary storage in identity — credentials must never self-delete
- DataKey: Admin, Issuer(Address), Credential(BytesN<32>), SubjectCreds(Address)

Estimate: 1 day" \
  "IDB-1 — Identity contract types and storage layout")
echo "IDB-1 = $IDB1"
chainlink milestone add $M_IDB $IDB1 -q 2>/dev/null || true
chainlink issue block $IDB1 $INF4 -q 2>/dev/null || true

IDB2=$($CL issue create \
  -p high \
  -l "contracts" -l "identity" \
  -d "Identity contract implementation and tests.

Acceptance Criteria:
- register_issuer(env, admin, issuer_address) — admin-only; emits IssuerRegistered
- issue_credential(env, issuer, subject, role, expires_at) -> BytesN<32> — returns cred_id; emits CredentialIssued
- revoke_credential(env, issuer_or_admin, cred_id) — marks status = Revoked; emits CredentialRevoked
- verify_credential(env, cred_id, expected_subject, expected_role) -> bool — O(1) lookup, no iteration
- All test cases pass: issue, verify, revoke, verify-after-revoke, expired check, wrong-subject check

Technical Notes:
- verify_credential is called cross-contract from broker and prescription — must be O(1) by cred_id
- Event emit uses u32 role_code discriminant so consumers can filter without decoding Symbol
- Issuer must be registered before issuing credentials

Estimate: 2 days" \
  "IDB-2 — Identity contract implementation and tests")
echo "IDB-2 = $IDB2"
chainlink milestone add $M_IDB $IDB2 -q 2>/dev/null || true
chainlink issue block $IDB2 $IDB1 -q 2>/dev/null || true

echo ""
echo "=== EPIC BKR — Access Broker Contract ==="

BKR1=$($CL issue create \
  -p critical \
  -l "contracts" -l "broker" -l "security" \
  -d "Access broker contract types, storage layout, and errors.

READ docs/claude/access-broker-contract-design.md IN FULL before writing any code. The bug catalog in §5 (Holes A-I) describes exactly what must be prevented.

Acceptance Criteria:
- components/contracts/access-broker/src/types.rs matches the structs in the design doc: Tier, GrantType, RecordMeta, Grant, PresenceProof, CredentialProof, Capability, Error
- components/contracts/access-broker/src/storage.rs defines DataKey with explicit storage class for each variant
- Contract compiles to WASM

Storage class assignments:
- Admin, IssuerRoot = instance (always alive)
- Record(BytesN<32>) = persistent (clinical commitments must survive)
- Grant(BytesN<32>) for normal = persistent; for break-glass = temporary
- PatientToken(Address) = persistent
- SpentNonce(BytesN<32>) = temporary (MAX_PRESENCE_WINDOW = 300 ledgers)

CRITICAL: Every security check uses expires_at and reveal_at fields vs env.ledger().timestamp(), NEVER the storage TTL. This is Hole B.

Estimate: 1 day" \
  "BKR-1 — Broker types, storage layout, and errors")
echo "BKR-1 = $BKR1"
chainlink milestone add $M_BKR $BKR1 -q 2>/dev/null || true
chainlink issue block $BKR1 $INF4 -q 2>/dev/null || true
chainlink issue block $BKR1 $IDB1 -q 2>/dev/null || true

BKR2=$($CL issue create \
  -p high \
  -l "contracts" -l "broker" \
  -d "Record registration and patient token registration in the access broker.

Acceptance Criteria:
- register_record(env, owner, record_id, tier, category, sensitive, locator_bytes, commitment) — owner require_auth(); stores RecordMeta; emits RecordRegistered
- register_patient_token(env, patient, token_pubkey) — patient require_auth(); stores under PatientToken(patient)
- Tests: register a record, retrieve RecordMeta, register a token, verify token retrieval

Technical Notes:
- locator_bytes is Bytes (opaque) — contract never interprets it, only stores and returns it
- commitment is BytesN<32> — SHA-256 of ciphertext, verified off-chain by the reader
- Event: env.events().publish((symbol_short!(\"rec_reg\"), owner.clone()), (record_id.clone(), tier_code, category_code))

Estimate: 1 day" \
  "BKR-2 — Record registration and patient token registration")
echo "BKR-2 = $BKR2"
chainlink milestone add $M_BKR $BKR2 -q 2>/dev/null || true
chainlink issue block $BKR2 $BKR1 -q 2>/dev/null || true

BKR3=$($CL issue create \
  -p high \
  -l "contracts" -l "broker" \
  -d "Normal grant creation (Tier 3) and revocation.

Acceptance Criteria:
- create_normal_grant(env, patient, grantee, record_id, purpose, scope_category, expires_at) — patient require_auth(); verifies record exists and patient is owner; stores Grant with gtype=Normal, revoked=false, reveal_at=0; emits GrantCreated
- revoke(env, owner, grant_id) — owner require_auth(); verifies owner; sets revoked=true; emits GrantRevoked
- Test: create grant, read grant state, revoke, verify revoked state

Technical Notes:
- grant_id = sha256(grantee_bytes || record_id_bytes || now_bytes)
- reveal_at = 0 for normal grants (no veto window for patient-initiated consent)
- DO NOT store grants in a patient-indexed Vec — that is Hole H (metering DoS)
- Every grant lookup is DataKey::Grant(grant_id) — O(1) only

Estimate: 1 day" \
  "BKR-3 — Normal grant creation (Tier 3)")
echo "BKR-3 = $BKR3"
chainlink milestone add $M_BKR $BKR3 -q 2>/dev/null || true
chainlink issue block $BKR3 $BKR2 -q 2>/dev/null || true
chainlink issue block $BKR3 $IDB2 -q 2>/dev/null || true

BKR4=$($CL issue create \
  -p critical \
  -l "contracts" -l "broker" -l "security" \
  -d "request_access and the on-chain predicate check — most security-critical function in the system.

Acceptance Criteria:
- request_access(env, requester, record_id, purpose, cred, presence) -> Capability implements the full flow:
  (0) require_auth, (1) verify credential, (2) authorize by tier, (3) EMIT AUDIT EVENT, (4) store grant, (5) return non-secret Capability
- Audit event emitted at step (3) BEFORE Capability is built — no code path returns Capability without audit (Hole I)
- Capability { grant_id, locator, commitment } contains NO secret material
- Simulation of request_access does NOT commit a grant and does NOT emit an event (verified by test)
- All Error variants have tests triggering them

Bug Catalog — every line reviewed against these before merge:
- Hole A: Capability has no secret; KMS releases only against committed on-chain state
- Hole B: if now >= g.expires_at { panic } — check field, not TTL
- Hole C: KMS re-reads state on every call
- Hole D: verify_presence checks registered token pubkey; nonce stored in SpentNonce
- Hole E: if cred.subject != requester { panic Error::CredentialNotForCaller }
- Hole F: if meta.sensitive && g.scope_category != meta.category { panic }
- Hole I: event emit precedes Capability construction on ALL authorization paths

Estimate: 2 days" \
  "BKR-4 — request_access and the on-chain predicate check")
echo "BKR-4 = $BKR4"
chainlink milestone add $M_BKR $BKR4 -q 2>/dev/null || true
chainlink issue block $BKR4 $BKR3 -q 2>/dev/null || true

BKR5=$($CL issue create \
  -p critical \
  -l "contracts" -l "broker" -l "security" -l "emergency" \
  -d "Break-glass grant and conscious-patient veto window.

Acceptance Criteria:
- Break-glass path in request_access for Tier::EmergencyBundle: credential must have role responder or clinician
- reveal_at = now + window_for(&meta): 0 for critical instant subset (allergies, implants), 30s for extended bundle
- veto(env, owner, grant_id) — owner require_auth(); checks now < grant.reveal_at else Error::WindowClosed; sets vetoed=true; emits GrantVetoed
- Tokenless fallback emits 'fallback' event with distinct topic
- Tests: presence path succeeds, nonce replay fails, wrong token fails, veto within window succeeds, veto after window fails

Technical Notes:
- Presence signature msg domain-separation: \"hcstellar:presence:v1\" || requester || record_id || nonce || expires_at_be
- ed25519_verify via env.crypto().ed25519_verify()
- Spent nonce TTL: extend_ttl(SpentNonce(nonce), MAX_PRESENCE_WINDOW=300, MAX_PRESENCE_WINDOW)
- Break-glass grants use temporary storage but expires_at field = now + BREAK_GLASS_WINDOW is the security clock

Estimate: 2 days" \
  "BKR-5 — Break-glass grant and veto")
echo "BKR-5 = $BKR5"
chainlink milestone add $M_BKR $BKR5 -q 2>/dev/null || true
chainlink issue block $BKR5 $BKR4 -q 2>/dev/null || true

BKR6=$($CL issue create \
  -p medium \
  -l "contracts" -l "broker" -l "audit" \
  -d "Delayed offline audit submission for Tier 1 card reads.

Acceptance Criteria:
- submit_delayed_audit(env, submitter, audit_payload_hash, device_sig, read_at, card_id) — verifies device signature over (domain || card_id || audit_payload_hash || read_at); emits DelayedAuditSubmitted with delayed=true
- Tests: valid submission emits event, bad device sig panics, replay of same (card_id, read_at) rejected (spent nonce)

Technical Notes:
- Device key registered in DataKey::CardDevice(BytesN<32>) persistent entry at offline card creation
- Emit topic: (symbol_short!(\"audit_off\"), card_id) — distinct from online audit events for indexer tagging

Estimate: 1 day" \
  "BKR-6 — Delayed offline audit submission")
echo "BKR-6 = $BKR6"
chainlink milestone add $M_BKR $BKR6 -q 2>/dev/null || true
chainlink issue block $BKR6 $BKR5 -q 2>/dev/null || true

echo ""
echo "=== EPIC KMS — KMS Gate Service ==="

KMS1=$($CL issue create \
  -p critical \
  -l "kms" -l "security" \
  -d "KMS gate scaffold and Stellar committed-state reader.

Acceptance Criteria:
- components/kms-gate/src/stellar/BrokerStateReader.ts fetches a grant entry from committed Stellar ledger state using getLedgerEntries — NOT simulateTransaction
- BrokerStateReader.readGrant(grantId: string): Promise<AccessGrant | null> returns null if entry doesn't exist
- A grant that was only simulated (never submitted) returns null

Technical Notes:
- Use @stellar/stellar-sdk server.getLedgerEntries() constructing ledger key from access-broker contract ID and DataKey::Grant(grant_id)
- Add comment at call site: '// COMMITTED STATE: do not change to simulateTransaction — see docs/claude/kms-lit-integration-spec.md §4'
- STELLAR_RPC_URL and BROKER_CONTRACT_ID injected via env vars from Docker Compose

Estimate: 1 day" \
  "KMS-1 — KMS gate scaffold and Stellar state reader")
echo "KMS-1 = $KMS1"
chainlink milestone add $M_KMS $KMS1 -q 2>/dev/null || true
chainlink issue block $KMS1 $INF3 -q 2>/dev/null || true
chainlink issue block $KMS1 $DOM2 -q 2>/dev/null || true

KMS2=$($CL issue create \
  -p critical \
  -l "kms" -l "security" \
  -d "Release predicate evaluator and key store stub.

Acceptance Criteria:
- components/kms-gate/src/predicate/ReleasePredicateEvaluator.ts IMPORTS evaluateReleasePredicate from @medichain/domain — does NOT reimplement it
- components/kms-gate/src/keys/LocalKeyStore.ts is a stub: returns a deterministic wrapped AES-256 key for a given grantId (stub; will be replaced by Lit Protocol later)
- All 8 deny cases from DOM-2 tests pass against the evaluator in integration

This is the 'stub decentralization, never stub the predicate' boundary — the key store is the stub, not the predicate.

Estimate: 1 day" \
  "KMS-2 — Release predicate evaluator and key store stub")
echo "KMS-2 = $KMS2"
chainlink milestone add $M_KMS $KMS2 -q 2>/dev/null || true
chainlink issue block $KMS2 $KMS1 -q 2>/dev/null || true

KMS3=$($CL issue create \
  -p critical \
  -l "kms" -l "security" -l "api" \
  -d "HTTP API for key release.

Acceptance Criteria:
- POST /v1/release accepts { grantId, requester, requesterAuth, locator }
- Returns { wrappedKey: string } on allow, { denied: true, reason: string } on deny
- requesterAuth verified as Ed25519 signature over sha256('hcstellar:kms:v1:' + grantId) using requester public key — prevents replay
- Rate limiting: max 10 release requests per requester per minute
- All deny branches return HTTP 403, not 500
- Every request logged with { grantId, requester, decision, reason, timestamp } — this log is the KMS audit trail

Estimate: 1 day" \
  "KMS-3 — HTTP API for key release")
echo "KMS-3 = $KMS3"
chainlink milestone add $M_KMS $KMS3 -q 2>/dev/null || true
chainlink issue block $KMS3 $KMS2 -q 2>/dev/null || true

KMS4=$($CL issue create \
  -p critical \
  -l "kms" -l "security" -l "testing" \
  -d "Conformance test suite — the predicate truth table. CI must run this on every PR.

Acceptance Criteria:
- components/kms-gate/src/test-vectors/conformance.test.ts has 15+ grant states with expected decisions
- Every row tested against both evaluateReleasePredicate (pure) AND the live KMS HTTP endpoint — must agree
- CI runs this suite on every PR

Required test vectors:
1. grant=null → NO_GRANT
2. grant.grantee !== caller → WRONG_REQUESTER
3. grant.revoked=true → REVOKED
4. grant.vetoed=true → VETOED
5. now < grant.revealAt → BEFORE_REVEAL
6. now = grant.expiresAt (boundary) → EXPIRED
7. now > grant.expiresAt → EXPIRED
8. All conditions met, revealAt=0 → allow
9. All conditions met, now=grant.revealAt → allow
10. revoked=true AND vetoed=true → REVOKED (revocation checked first)
11. Break-glass, veto window open, patient vetoed → VETOED
12. Break-glass, past revealAt, not vetoed → allow
13. Normal grant, revealAt=0, not revoked → allow
14. Expired grant that was previously allowed → EXPIRED (re-checked every call)
15. Simulated (never committed) request_access → NO_GRANT

Estimate: 1 day" \
  "KMS-4 — Conformance test suite (predicate truth table)")
echo "KMS-4 = $KMS4"
chainlink milestone add $M_KMS $KMS4 -q 2>/dev/null || true
chainlink issue block $KMS4 $KMS3 -q 2>/dev/null || true

echo ""
echo "=== EPIC STR — Storage & Crypto ==="

STR1=$($CL issue create \
  -p high \
  -l "storage" \
  -d "Storage provider interface and MinIO implementation.

Acceptance Criteria:
- components/packages/storage/src/RecordStorageProvider.ts defines the interface: store(Uint8Array) -> Promise<RecordLocator>, retrieve(RecordLocator) -> Promise<Uint8Array>
- components/packages/storage/src/MinioRecordStorageProvider.ts implements it
- Bucket medichain-records auto-created on first use if missing
- store returns RecordLocator with locatorType='s3' and contentCommitment = SHA-256 of stored bytes
- retrieve verifies SHA-256 against locator.contentCommitment before returning — tampered blobs throw CommitmentMismatchError

Technical Notes:
- MinIO endpoint: http://minio:9000 in Docker Compose
- Check Verdaccio cache for minio npm client before unlocking npmjs
- Object key: records/\${sha256(payload).hex} — content-addressed, duplicate payloads deduplicate

Estimate: 2 days" \
  "STR-1 — Storage provider interface and MinIO implementation")
echo "STR-1 = $STR1"
chainlink milestone add $M_STR $STR1 -q 2>/dev/null || true
chainlink issue block $STR1 $INF3 -q 2>/dev/null || true
chainlink issue block $STR1 $INF2 -q 2>/dev/null || true

STR2=$($CL issue create \
  -p critical \
  -l "storage" -l "crypto" -l "security" \
  -d "Envelope encryption service for clinical payloads.

Acceptance Criteria:
- components/packages/crypto/src/EnvelopeEncryptionService.ts: encrypt(plaintext) -> { ciphertext, wrappedKey, keyId }; decrypt(ciphertext, wrappedKey) -> plaintext
- AES-256-GCM for payload encryption; per-record random 256-bit DEK
- components/packages/crypto/src/CommitmentService.ts computes sha256(ciphertext) and returns hex
- Tests: encrypt → commitment → store → retrieve → verify commitment → decrypt → matches plaintext

Technical Notes:
- Use Node's built-in crypto module (createCipheriv('aes-256-gcm', ...)) — no external crypto library needed
- wrappedKey = base64(encrypt_with_master_key(DEK)) where master key is held by kms-gate at startup
- Stub: kms-gate single service holds master key. In production: Lit Protocol threshold KMS.
- The predicate is still real: kms-gate only returns wrappedKey after evaluateReleasePredicate passes

Estimate: 2 days" \
  "STR-2 — Envelope encryption service")
echo "STR-2 = $STR2"
chainlink milestone add $M_STR $STR2 -q 2>/dev/null || true
chainlink issue block $STR2 $STR1 -q 2>/dev/null || true

echo ""
echo "=== EPIC IDX — API-Indexer Service ==="

IDX1=$($CL issue create \
  -p high \
  -l "indexer" -l "database" \
  -d "Postgres schema and migrations for the api-indexer.

Acceptance Criteria:
- components/api-indexer/src/storage/migrations/001_initial.sql creates all tables
- Tables: grants, records, audit_events, prescriptions, inventory_units, credentials, notifications, _indexer_state
- Migration runs automatically on api-indexer startup
- All foreign keys defined; indexes on grants.grantee, grants.record_id, audit_events.patient_pseudonym

Key table schemas:
- grants: grant_id CHAR(64) PK, record_id, grantee VARCHAR(56), grant_type, reveal_at BIGINT, expires_at BIGINT, revoked BOOL, vetoed BOOL
- audit_events: event_id BIGSERIAL PK, event_type VARCHAR(64), tier, patient_pseudonym, reader_ref, grant_id, delayed BOOL, raw_event JSONB, ledger_sequence BIGINT
- _indexer_state: key VARCHAR(64) PK, value TEXT (stores last_ledger cursor)

Estimate: 1 day" \
  "IDX-1 — Postgres schema and migrations")
echo "IDX-1 = $IDX1"
chainlink milestone add $M_IDX $IDX1 -q 2>/dev/null || true
chainlink issue block $IDX1 $INF3 -q 2>/dev/null || true

IDX2=$($CL issue create \
  -p high \
  -l "indexer" \
  -d "Event ingestor — Soroban event poller into Postgres.

Acceptance Criteria:
- components/api-indexer/src/events/EventIngestor.ts polls getEvents on Stellar RPC for all 4 contract event streams
- Each event decoded and upserted into appropriate Postgres table
- Ingestor stores last processed ledger sequence and resumes from there on restart (no re-processing)
- Events handled: access, revoke, veto, fallback, audit_off, cred_issue, cred_revoke, rec_reg

Technical Notes:
- SorobanRpc.Server.getEvents({ startLedger, filters: [{ type: 'contract', contractIds: [...] }] })
- Cursor in _indexer_state: key='last_ledger'
- Poll interval: 5 seconds in development; configurable via EVENT_POLL_INTERVAL_MS env var

Estimate: 2 days" \
  "IDX-2 — Event ingestor (Soroban event poller)")
echo "IDX-2 = $IDX2"
chainlink milestone add $M_IDX $IDX2 -q 2>/dev/null || true
chainlink issue block $IDX2 $IDX1 -q 2>/dev/null || true
chainlink issue block $IDX2 $BKR4 -q 2>/dev/null || true

IDX3=$($CL issue create \
  -p high \
  -l "indexer" -l "emergency" \
  -d "Veto-window notification workflow.

Acceptance Criteria:
- When a break-glass grant event is indexed with reveal_at > now, a notification is scheduled for the patient
- Notification stored in notifications Postgres table AND logged — no external email/SMS in MVP
- Notification includes: grantId, grantee (responder), revealAt, expiresAt, deep-link to veto action
- After revealAt passes without veto, notification status set to 'window_closed'

Technical Notes:
- VetoWindowWorkflow.ts runs every 5 seconds: checks grants WHERE grant_type='break_glass' AND reveal_at > NOW() AND NOT revoked AND NOT vetoed
- Web app polls GET /v1/notifications?patient=<address> for pending veto alerts

Estimate: 1 day" \
  "IDX-3 — Veto-window notification workflow")
echo "IDX-3 = $IDX3"
chainlink milestone add $M_IDX $IDX3 -q 2>/dev/null || true
chainlink issue block $IDX3 $IDX2 -q 2>/dev/null || true

IDX4=$($CL issue create \
  -p medium \
  -l "indexer" -l "api" \
  -d "REST API routes for the api-indexer.

Acceptance Criteria:
- GET /v1/grants?patient=<address> — active grants for a patient
- GET /v1/audit?patient=<address> — audit events (online + delayed-offline, sorted by timestamp)
- GET /v1/notifications?patient=<address> — pending veto alerts
- GET /v1/records?patient=<address> — record metadata (no PHI)
- GET /v1/health — returns { ok: true }
- All routes return camelCase JSON; NO PHI in any response

Estimate: 1 day" \
  "IDX-4 — REST API routes")
echo "IDX-4 = $IDX4"
chainlink milestone add $M_IDX $IDX4 -q 2>/dev/null || true
chainlink issue block $IDX4 $IDX1 -q 2>/dev/null || true
chainlink issue block $IDX4 $IDX2 -q 2>/dev/null || true

echo ""
echo "=== EPIC WLT — Wallet Integration ==="

WLT1=$($CL issue create \
  -p high \
  -l "wallet" -l "typescript" \
  -d "WalletAdapter interface and MockWalletAdapter — replaces the current prompt() wallet.

Acceptance Criteria:
- components/packages/wallet/src/WalletAdapter.ts defines: getPublicKey(): Promise<string>, signTransaction(xdr, network): Promise<string>, isConnected(): Promise<bool>
- components/packages/wallet/src/MockWalletAdapter.ts implements it with a hardcoded test keypair — used by E2E tests
- Current src/hooks/useWallet.ts (localStorage-based, no signing) replaced by components/web/src/hooks/useWallet.ts wrapping a WalletAdapter

Estimate: 1 day" \
  "WLT-1 — WalletAdapter interface and MockWalletAdapter")
echo "WLT-1 = $WLT1"
chainlink milestone add $M_WLT $WLT1 -q 2>/dev/null || true
chainlink issue block $WLT1 $INF2 -q 2>/dev/null || true

WLT2=$($CL issue create \
  -p high \
  -l "wallet" \
  -d "Freighter wallet adapter — connects the web app to Freighter for real transaction signing.

Acceptance Criteria:
- components/packages/wallet/src/FreighterWalletAdapter.ts wraps @stellar/freighter-api
- getPublicKey() calls freighter.getPublicKey()
- signTransaction() calls freighter.signTransaction(xdr, { network })
- If Freighter not installed, isConnected() returns false and getPublicKey() throws FreighterNotInstalledError
- The web app's connect button invokes the adapter, not prompt()

Technical Notes:
- Check Verdaccio cache for @stellar/freighter-api first — may already be cached
- components/packages/wallet/src/index.ts exports factory: createWalletAdapter(type: 'freighter' | 'mock')

Estimate: 1 day" \
  "WLT-2 — Freighter wallet adapter")
echo "WLT-2 = $WLT2"
chainlink milestone add $M_WLT $WLT2 -q 2>/dev/null || true
chainlink issue block $WLT2 $WLT1 -q 2>/dev/null || true

echo ""
echo "=== EPIC T3 — Tier 3: Full Clinical History Flow ==="

T31=$($CL issue create \
  -p high \
  -l "tier3" -l "patient" \
  -d "Patient stores an encrypted clinical record (first vertical slice touching every layer).

Acceptance Criteria:
- components/web/src/app/(patient)/store-record/page.tsx allows patient to upload a clinical record (JSON)
- Record encrypted via EnvelopeEncryptionService, stored in MinIO via MinioRecordStorageProvider
- Commitment and locator registered on broker via register_record
- Transaction signed by Freighter
- After submission, patient sees record in dashboard with commitment and tier badge

Technical Notes:
- components/packages/stellar-client/src/AccessBrokerContractClient.ts wraps register_record invocation
- Migrate existing dashboard from src/app/dashboard/page.tsx → components/web/src/app/(patient)/dashboard/page.tsx

Estimate: 2 days" \
  "T3-1 — Store encrypted record (patient side)")
echo "T3-1 = $T31"
chainlink milestone add $M_T3 $T31 -q 2>/dev/null || true
chainlink issue block $T31 $STR2 -q 2>/dev/null || true
chainlink issue block $T31 $BKR2 -q 2>/dev/null || true
chainlink issue block $T31 $WLT2 -q 2>/dev/null || true

T32=$($CL issue create \
  -p high \
  -l "tier3" -l "patient" \
  -d "Patient grants access to a clinician and can revoke.

Acceptance Criteria:
- Patient selects a record, enters clinician Stellar address, sets scope category and expiry, calls create_normal_grant
- Grant submitted and confirmed on-chain
- Patient dashboard shows active grant with revoke button
- Revoke calls revoke(grant_id) and grant disappears after indexer updates

Estimate: 1 day" \
  "T3-2 — Grant access to clinician (patient side)")
echo "T3-2 = $T32"
chainlink milestone add $M_T3 $T32 -q 2>/dev/null || true
chainlink issue block $T32 $T31 -q 2>/dev/null || true

T33=$($CL issue create \
  -p critical \
  -l "tier3" -l "clinician" -l "kms" \
  -d "Clinician reads a record through the full KMS predicate — the core access flow end-to-end.

Acceptance Criteria:
- Clinician calls request_access(record_id, ...) — broker returns Capability { grantId, locator, commitment }
- Clinician app sends POST /v1/release to kms-gate with grantId and requesterAuth
- KMS reads committed Stellar state, evaluates predicate, returns wrappedKey
- Clinician app retrieves ciphertext from MinIO, verifies SHA-256 against commitment, decrypts
- Clinician sees plaintext record in components/web/src/app/(clinician)/record-view/page.tsx
- If grant revoked between request_access and KMS release, KMS returns { denied: true, reason: 'REVOKED' } and UI shows error

Estimate: 2 days" \
  "T3-3 — Clinician reads record through KMS predicate")
echo "T3-3 = $T33"
chainlink milestone add $M_T3 $T33 -q 2>/dev/null || true
chainlink issue block $T33 $T32 -q 2>/dev/null || true
chainlink issue block $T33 $KMS3 -q 2>/dev/null || true
chainlink issue block $T33 $IDX2 -q 2>/dev/null || true

echo ""
echo "=== EPIC T2 — Tier 2: Break-Glass + Veto Window ==="

T21=$($CL issue create \
  -p high \
  -l "tier2" -l "patient" -l "emergency" \
  -d "Patient creates a Tier 2 emergency bundle with its own encryption key.

Acceptance Criteria:
- Patient creates Tier 2 emergency bundle from dashboard — selects which records contribute
- Bundle separately encrypted with its own DEK (distinct from Tier 3 record keys)
- Commitment and locator registered on broker with tier=EmergencyBundle
- Bundle schema matches docs/clinical-history-tiers.md Tier 2 data format

Estimate: 1 day" \
  "T2-1 — Tier 2 emergency bundle construction and storage")
echo "T2-1 = $T21"
chainlink milestone add $M_T2 $T21 -q 2>/dev/null || true
chainlink issue block $T21 $T31 -q 2>/dev/null || true

T22=$($CL issue create \
  -p critical \
  -l "tier2" -l "responder" -l "emergency" \
  -d "Responder initiates break-glass access with veto countdown.

Acceptance Criteria:
- components/web/src/app/(responder)/emergency-access/page.tsx allows credentialed responder to initiate break-glass
- Responder provides: patient lookup (address or card scan), credential proof, presence proof (if available), reason code
- request_access called with tier=EmergencyBundle; broker emits audit event, creates grant with reveal_at=now+30
- UI shows countdown to revealAt and 'pending veto window' state
- After revealAt passes without veto, UI auto-triggers KMS release
- KMS release and read follow T3-3 pattern

Estimate: 2 days" \
  "T2-2 — Break-glass access request (responder side)")
echo "T2-2 = $T22"
chainlink milestone add $M_T2 $T22 -q 2>/dev/null || true
chainlink issue block $T22 $T21 -q 2>/dev/null || true
chainlink issue block $T22 $BKR5 -q 2>/dev/null || true
chainlink issue block $T22 $WLT2 -q 2>/dev/null || true

T23=$($CL issue create \
  -p critical \
  -l "tier2" -l "patient" -l "emergency" -l "security" \
  -d "Conscious-patient veto of a break-glass request.

Acceptance Criteria:
- Patient app (via GET /v1/notifications) shows live veto alert: 'Emergency access requested by [responder]. Expires in [countdown]. Tap to veto.'
- Patient calls veto(grant_id) before revealAt — signed by Freighter
- After veto confirmed on-chain and indexed, responder UI shows 'Access vetoed by patient'
- KMS release attempt for vetoed grant returns { denied: true, reason: 'VETOED' }
- Test: veto at revealAt-5s → denied; veto attempt at revealAt+1s → WindowClosed error from contract

Estimate: 1 day" \
  "T2-3 — Conscious-patient veto")
echo "T2-3 = $T23"
chainlink milestone add $M_T2 $T23 -q 2>/dev/null || true
chainlink issue block $T23 $T22 -q 2>/dev/null || true
chainlink issue block $T23 $IDX3 -q 2>/dev/null || true

T24=$($CL issue create \
  -p high \
  -l "tier2" -l "responder" -l "emergency" \
  -d "Tokenless fallback path when no patient presence proof is available.

Acceptance Criteria:
- When no presence proof provided, broker routes to tokenless fallback in authorize_emergency
- Fallback requires dual co-sign: primary responder credential + second clinician or institution credential
- UI: after primary submits, second approver must confirm before grant is created
- Fallback grants emit 'fallback' audit topic; indexer tags them grant_type='tokenless_fallback'
- Fallback only authorizes vital subset (records marked sensitive=false in critical category)

Estimate: 1 day" \
  "T2-4 — Tokenless fallback path")
echo "T2-4 = $T24"
chainlink milestone add $M_T2 $T24 -q 2>/dev/null || true
chainlink issue block $T24 $T22 -q 2>/dev/null || true

echo ""
echo "=== EPIC T1 — Tier 1: Offline Emergency Card ==="

T11=$($CL issue create \
  -p high \
  -l "tier1" -l "patient" -l "offline" \
  -d "Patient generates a self-verifying signed offline emergency card (QR + NFC).

Acceptance Criteria:
- Patient creates offline emergency card from the dashboard
- Card payload matches docs/clinical-history-tiers.md Tier 1 schema: allergies, critical meds, major conditions, implants, directive flag, emergency contacts, pointer to Tier 2 bundle
- Card payload signed by patient's key (Ed25519 via Freighter) — signature covers all non-signature fields
- Card encoded as QR code and NFC NDEF record URI; available for download/print
- offlineAudit.budgetId registered on-chain (DataKey::CardDevice) with remainingReads=50

Technical Notes:
- Card payload is JSON, canonically serialized (sorted keys) before signing — required for deterministic sig verification
- Check Verdaccio cache for qrcode npm library

Estimate: 2 days" \
  "T1-1 — Offline card generation and signing")
echo "T1-1 = $T11"
chainlink milestone add $M_T1 $T11 -q 2>/dev/null || true
chainlink issue block $T11 $STR2 -q 2>/dev/null || true
chainlink issue block $T11 $BKR2 -q 2>/dev/null || true

T12=$($CL issue create \
  -p high \
  -l "tier1" -l "responder" -l "offline" \
  -d "Offline card reader and deferred audit submission for responders.

Acceptance Criteria:
- components/web/src/app/(responder)/offline-card/page.tsx accepts QR scan or file paste of card JSON
- Responder app verifies card signature using token_pubkey from the card payload
- On verification success, displays card contents (allergies, meds, conditions)
- Creates local deferred audit record in localStorage: { cardId, readAtDeviceTime, responderRef, deviceSignature }
- When network returns, responder app calls submit_delayed_audit on broker contract
- Submitted delayed audit shows in patient audit log with delayed=true

Estimate: 2 days" \
  "T1-2 — Offline card reader and deferred audit submission")
echo "T1-2 = $T12"
chainlink milestone add $M_T1 $T12 -q 2>/dev/null || true
chainlink issue block $T12 $T11 -q 2>/dev/null || true
chainlink issue block $T12 $BKR6 -q 2>/dev/null || true

echo ""
echo "=== EPIC RX — Prescription Contract ==="

RX1=$($CL issue create \
  -p high \
  -l "contracts" -l "prescription" \
  -d "Prescription contract types and storage layout — the bridge object.

Acceptance Criteria:
- components/contracts/prescription/src/types.rs defines PrescriptionState, Prescription, Reservation, DispensationReceipt
- Prescription(BytesN<32>) = persistent; Reservation(BytesN<32>) = temporary (escrow auto-expires)
- Contract compiles to WASM

Technical Notes:
- Prescription.drug_class is Symbol (public) — NOT diagnosis, NOT patient name
- prescription_id = sha256(patient_pseudonym || nonce || issued_at) — unlinkable across prescriptions
- PrescriptionState: Issued, Reserved, Dispensed, Closed, Expired, Cancelled

Estimate: 1 day" \
  "RX-1 — Prescription contract types and storage")
echo "RX-1 = $RX1"
chainlink milestone add $M_RX $RX1 -q 2>/dev/null || true
chainlink issue block $RX1 $INF4 -q 2>/dev/null || true
chainlink issue block $RX1 $IDB1 -q 2>/dev/null || true

RX2=$($CL issue create \
  -p high \
  -l "contracts" -l "prescription" \
  -d "Prescription issuance and inventory reservation.

Acceptance Criteria:
- issue_prescription(env, clinician, patient_pseudonym, drug_class, expires_at) -> BytesN<32> — clinician require_auth(); credential check via cross-contract call to identity; emits PrescriptionIssued
- reserve(env, patient, prescription_id, pharmacy_address, unit_id) -> BytesN<32> — patient require_auth(); cross-contract call to supplychain to lock unit; emits PrescriptionReserved; state → Reserved
- Tests: issue, reserve, attempt double-reserve (fails), cancel reservation

Technical Notes:
- Cross-contract: env.invoke_contract(&supply_chain_id, &symbol_short!(\"reserve_unit\"), vec![unit_id, prescription_id])
- Supply chain contract ID in instance storage as DataKey::SupplychainId
- reservation_ref = sha256(prescription_id || unit_id || patient_pseudonym) — unlinkable

Estimate: 2 days" \
  "RX-2 — Prescription issuance and reservation")
echo "RX-2 = $RX2"
chainlink milestone add $M_RX $RX2 -q 2>/dev/null || true
chainlink issue block $RX2 $RX1 -q 2>/dev/null || true
chainlink issue block $RX2 $IDB2 -q 2>/dev/null || true

RX3=$($CL issue create \
  -p critical \
  -l "contracts" -l "prescription" -l "security" \
  -d "Dispensation with patient active co-signature and dispensation receipt writeback.

THE MOST IMPORTANT TEST: dispense with only pharmacy sig must fail. This is the anti-ghost-dispense control.

Acceptance Criteria:
- dispense(env, pharmacy, patient, prescription_id, dispensation_receipt_commitment) — requires BOTH pharmacy.require_auth() AND patient.require_auth() in the same transaction
- Calls supplychain dispense_unit cross-contract
- Calls access broker register_record cross-contract to commit dispensation receipt back to patient Tier 3 record
- State → Dispensed; emits PrescriptionDispensed
- Test: dispense with only pharmacy sig FAILS

Technical Notes:
- In Soroban, both pharmacy.require_auth() and patient.require_auth() in same function — Soroban validates both in the auth DAG
- dispensation_receipt_commitment = BytesN<32> SHA-256 of encrypted dispensation JSON (stored in MinIO by pharmacy before calling dispense)

Estimate: 2 days" \
  "RX-3 — Dispensation with patient active co-signature and receipt writeback")
echo "RX-3 = $RX3"
chainlink milestone add $M_RX $RX3 -q 2>/dev/null || true
chainlink issue block $RX3 $RX2 -q 2>/dev/null || true
chainlink issue block $RX3 $BKR3 -q 2>/dev/null || true

echo ""
echo "=== EPIC SC — Supply-Chain Contract ==="

SC1=$($CL issue create \
  -p high \
  -l "contracts" -l "supplychain" \
  -d "Supply-chain contract types and storage layout.

Acceptance Criteria:
- components/contracts/supplychain/src/types.rs defines: DrugProduct, DrugBatch, BatchStatus, InventoryUnit, UnitStatus, CustodyRecord, ColdChainStatus, OpposingInterestAttestation
- BatchStatus: Available, Reserved, Dispensed, Quarantined, Expired
- Storage: Batch(BytesN<32>) persistent, Unit(BytesN<32>) persistent, BatchUnits(BytesN<32>) persistent (manifest), ColdChainLog(BytesN<32>) temporary
- Contract compiles to WASM

Estimate: 1 day" \
  "SC-1 — Supply-chain contract types and storage")
echo "SC-1 = $SC1"
chainlink milestone add $M_SC $SC1 -q 2>/dev/null || true
chainlink issue block $SC1 $INF4 -q 2>/dev/null || true

SC2=$($CL issue create \
  -p high \
  -l "contracts" -l "supplychain" \
  -d "Drug batch registration and unit serialization.

Acceptance Criteria:
- register_batch(env, manufacturer, gtin, lot_number, expiry_date, unit_count) -> BytesN<32> — manufacturer credential required; emits BatchRegistered
- serialize_unit(env, manufacturer, batch_id, serial_number) -> BytesN<32> — creates InventoryUnit; emits UnitSerialized
- Tests: register batch, serialize units, query unit status

Estimate: 1 day" \
  "SC-2 — Batch registration and unit serialization")
echo "SC-2 = $SC2"
chainlink milestone add $M_SC $SC2 -q 2>/dev/null || true
chainlink issue block $SC2 $SC1 -q 2>/dev/null || true
chainlink issue block $SC2 $IDB2 -q 2>/dev/null || true

SC3=$($CL issue create \
  -p high \
  -l "contracts" -l "supplychain" -l "security" \
  -d "Custody transfer with opposing-interest attestation and cold-chain oracle.

Acceptance Criteria:
- transfer_custody(env, from, to, unit_id, opposing_attester_sig) — from.require_auth() AND opposing attester sig verified via env.crypto().ed25519_verify(); emits CustodyTransferred
- record_cold_chain(env, oracle, batch_id, temperature_c, timestamp) — oracle pre-registered; if temp outside range, calls quarantine_batch
- quarantine_batch(env, batch_id) — sets all units to Quarantined; reservation on quarantined units fails
- Tests: transfer custody, cold chain excursion triggers quarantine, reservation on quarantined batch fails

Technical Notes:
- opposing_attester_sig: attester must have opposing interest (pharmacy, regulatory body) — NOT just the receiving party
- This is the threat-model requirement from docs/claude/stellar-integrated-health-supply-plan_final.md §5.4 and §8

Estimate: 2 days" \
  "SC-3 — Custody transfer and cold-chain oracle")
echo "SC-3 = $SC3"
chainlink milestone add $M_SC $SC3 -q 2>/dev/null || true
chainlink issue block $SC3 $SC2 -q 2>/dev/null || true

SC4=$($CL issue create \
  -p high \
  -l "contracts" -l "supplychain" \
  -d "Inventory reservation and dispense — callable only by prescription contract.

Acceptance Criteria:
- reserve_unit(env, prescription_contract, unit_id, reservation_ref) — only callable by prescription contract; sets UnitStatus::Reserved; emits UnitReserved
- dispense_unit(env, prescription_contract, unit_id) — only callable by prescription contract; sets UnitStatus::Dispensed; emits UnitDispensed
- release_reservation(env, unit_id) — called by prescription contract on cancel/expire; sets unit back to Available
- Tests: reserve, dispense, reserve-then-release, attempt-reserve-on-quarantined

Estimate: 1 day" \
  "SC-4 — Inventory reservation and dispense")
echo "SC-4 = $SC4"
chainlink milestone add $M_SC $SC4 -q 2>/dev/null || true
chainlink issue block $SC4 $SC3 -q 2>/dev/null || true

echo ""
echo "=== EPIC WEB — Web App Integration ==="

WEB1=$($CL issue create \
  -p high \
  -l "web" -l "frontend" \
  -d "Role-based routing and layout for all five roles.

Acceptance Criteria:
- components/web/src/app/ has route groups: (patient), (clinician), (pharmacy), (responder), (admin)
- Each group has its own layout with role-appropriate navigation
- Wallet connection gate: all role pages redirect to /connect if no wallet connected
- Existing pages (src/app/dashboard, src/app/doctor) migrated into appropriate role groups

Design reference: use /design-dashboard and /design-saas-landing skills for layout patterns.

Estimate: 1 day" \
  "WEB-1 — Role-based routing and layout")
echo "WEB-1 = $WEB1"
chainlink milestone add $M_WEB $WEB1 -q 2>/dev/null || true
chainlink issue block $WEB1 $WLT2 -q 2>/dev/null || true
chainlink issue block $WEB1 $INF1 -q 2>/dev/null || true

WEB2=$($CL issue create \
  -p high \
  -l "web" -l "frontend" -l "patient" \
  -d "Patient dashboard: records, active grants, audit log, and veto alerts.

Acceptance Criteria:
- Patient dashboard shows: active records (with tier badges), active grants, audit event log, pending veto alerts
- Veto alerts show countdown timer until revealAt; veto button calls veto(grant_id) and is disabled after revealAt
- Revoking a grant calls revoke(grant_id) via Freighter
- All data fetched from api-indexer REST API — no direct contract calls from the dashboard

Estimate: 2 days" \
  "WEB-2 — Patient dashboard (records, grants, audit, veto alerts)")
echo "WEB-2 = $WEB2"
chainlink milestone add $M_WEB $WEB2 -q 2>/dev/null || true
chainlink issue block $WEB2 $WEB1 -q 2>/dev/null || true
chainlink issue block $WEB2 $T31 -q 2>/dev/null || true
chainlink issue block $WEB2 $T32 -q 2>/dev/null || true
chainlink issue block $WEB2 $IDX4 -q 2>/dev/null || true

WEB3=$($CL issue create \
  -p high \
  -l "web" -l "frontend" -l "clinician" \
  -d "Clinician workflow: request access, view record, write record, issue prescription.

Acceptance Criteria:
- Clinician looks up patient by address, requests access to record
- After KMS release, record displays with commitment verification badge ('Verified against on-chain commitment')
- Clinician writes new record entry (encrypted, committed to broker)
- Clinician issues prescription (drug class, expiry) — calls issue_prescription
- All actions require valid clinician credential (shown in UI; contract enforces)

Estimate: 2 days" \
  "WEB-3 — Clinician workflow")
echo "WEB-3 = $WEB3"
chainlink milestone add $M_WEB $WEB3 -q 2>/dev/null || true
chainlink issue block $WEB3 $T33 -q 2>/dev/null || true
chainlink issue block $WEB3 $RX2 -q 2>/dev/null || true
chainlink issue block $WEB3 $WEB1 -q 2>/dev/null || true

WEB4=$($CL issue create \
  -p high \
  -l "web" -l "frontend" -l "pharmacy" \
  -d "Pharmacy workflow: view reservations and dispense with patient co-signature.

Acceptance Criteria:
- Pharmacy sees incoming reservations from the indexer
- Dispense flow: pharmacy confirms, patient scans QR/NFC or enters confirmation code, both sigs submitted in same transaction
- After dispense, encrypted receipt commitment written back to patient's record
- Quarantined inventory units shown with warning badge and cannot be selected for dispense

Estimate: 1 day" \
  "WEB-4 — Pharmacy workflow (view reservations, dispense)")
echo "WEB-4 = $WEB4"
chainlink milestone add $M_WEB $WEB4 -q 2>/dev/null || true
chainlink issue block $WEB4 $RX3 -q 2>/dev/null || true
chainlink issue block $WEB4 $WEB1 -q 2>/dev/null || true

WEB5=$($CL issue create \
  -p high \
  -l "web" -l "frontend" -l "responder" -l "emergency" \
  -d "Responder emergency access workflow: offline card + online break-glass.

Acceptance Criteria:
- Responder can scan Tier 1 QR card (offline path) or initiate Tier 2 break-glass (online path)
- Offline path: verifies card signature, displays contents, queues deferred audit
- Online path: initiates break-glass, shows veto-window countdown, auto-triggers KMS release after window
- Tokenless fallback: if no presence proof available, prompts second clinician to co-sign

Estimate: 1 day" \
  "WEB-5 — Responder emergency access workflow")
echo "WEB-5 = $WEB5"
chainlink milestone add $M_WEB $WEB5 -q 2>/dev/null || true
chainlink issue block $WEB5 $T22 -q 2>/dev/null || true
chainlink issue block $WEB5 $T24 -q 2>/dev/null || true
chainlink issue block $WEB5 $T12 -q 2>/dev/null || true
chainlink issue block $WEB5 $WEB1 -q 2>/dev/null || true

echo ""
echo "=== EPIC E2E — End-to-End Tests ==="

E2E1=$($CL issue create \
  -p high \
  -l "e2e" -l "testing" \
  -d "E2E test infrastructure and mock wallet setup.

Acceptance Criteria:
- Playwright configured in e2e/ with playwright.config.ts pointing at http://web:3000
- MockWalletAdapter injected into test browser context via NEXT_PUBLIC_WALLET_ADAPTER=mock
- Seed data (patient, clinician, responder, pharmacy) automatically loaded before each test suite
- e2e/helpers/stellar.ts provides waitForTransaction(hash) and getGrantState(grantId) helpers

Estimate: 1 day" \
  "E2E-1 — Test infrastructure and mock wallet")
echo "E2E-1 = $E2E1"
chainlink milestone add $M_E2E $E2E1 -q 2>/dev/null || true
chainlink issue block $E2E1 $INF3 -q 2>/dev/null || true
chainlink issue block $E2E1 $WLT1 -q 2>/dev/null || true

E2E2=$($CL issue create \
  -p high \
  -l "e2e" -l "testing" -l "tier3" \
  -d "Tier 3 happy path and revocation conformance tests.

Acceptance Criteria:
- Test: patient stores record → grants clinician → clinician reads → verify commitment → record displayed
- Test: patient stores record → grants clinician → patient revokes → clinician KMS release attempt → returns REVOKED → UI shows error
- Test: grant expires naturally (short expiresAt) → KMS returns EXPIRED

Estimate: 1 day" \
  "E2E-2 — Tier 3 happy path and revocation test")
echo "E2E-2 = $E2E2"
chainlink milestone add $M_E2E $E2E2 -q 2>/dev/null || true
chainlink issue block $E2E2 $E2E1 -q 2>/dev/null || true
chainlink issue block $E2E2 $T33 -q 2>/dev/null || true

E2E3=$($CL issue create \
  -p critical \
  -l "e2e" -l "testing" -l "emergency" -l "security" \
  -d "Break-glass and veto conformance tests.

Acceptance Criteria:
- Test: responder opens break-glass → patient vetoes within window → KMS returns VETOED
- Test: responder opens break-glass → no veto → after revealAt → KMS returns key → record displayed
- Test: break-glass with tokenless fallback → requires second co-sign → after dual co-sign → access granted

Estimate: 1 day" \
  "E2E-3 — Break-glass and veto conformance tests")
echo "E2E-3 = $E2E3"
chainlink milestone add $M_E2E $E2E3 -q 2>/dev/null || true
chainlink issue block $E2E3 $E2E2 -q 2>/dev/null || true
chainlink issue block $E2E3 $T23 -q 2>/dev/null || true

E2E4=$($CL issue create \
  -p critical \
  -l "e2e" -l "testing" -l "prescription" \
  -d "Prescription bridge end-to-end test — the full closed loop.

Acceptance Criteria:
- Full loop: clinician writes diagnosis → issues prescription → patient selects pharmacy → pharmacy dispenses with patient co-sign → dispensation receipt appears in patient Tier 3 record
- Test: pharmacy-only dispense (no patient sig) → transaction fails
- Test: reserve against quarantined batch → reservation fails with BatchQuarantined error

Estimate: 2 days" \
  "E2E-4 — Prescription bridge end-to-end test")
echo "E2E-4 = $E2E4"
chainlink milestone add $M_E2E $E2E4 -q 2>/dev/null || true
chainlink issue block $E2E4 $E2E3 -q 2>/dev/null || true
chainlink issue block $E2E4 $RX3 -q 2>/dev/null || true
chainlink issue block $E2E4 $SC4 -q 2>/dev/null || true

E2E5=$($CL issue create \
  -p critical \
  -l "e2e" -l "testing" -l "security" \
  -d "KMS predicate security conformance test — the final proof of correctness.

Acceptance Criteria:
- The KMS-4 conformance test vector table is executed end-to-end: each vector creates corresponding Stellar ledger state, then calls KMS HTTP endpoint, verifies response matches expected decision
- Test confirms simulated (never-submitted) request_access produces no usable key release — simulation-scrape defense test
- All 15 test vectors pass

This is the exit criterion for the MVP: when E2E-5 passes, the system is correct.

Estimate: 1 day" \
  "E2E-5 — KMS predicate security conformance test")
echo "E2E-5 = $E2E5"
chainlink milestone add $M_E2E $E2E5 -q 2>/dev/null || true
chainlink issue block $E2E5 $E2E4 -q 2>/dev/null || true
chainlink issue block $E2E5 $KMS4 -q 2>/dev/null || true

echo ""
echo "=== All tasks created. Summary ==="
chainlink issue list 2>&1 | head -60
echo ""
echo "Ready issues (no open blockers):"
chainlink issue ready 2>&1
