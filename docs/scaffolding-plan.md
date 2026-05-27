# Scaffolding Plan

## Purpose

This plan turns the proposed software architecture into a concrete workspace shape before functional implementation begins. The goal is to create the Rust and TypeScript module boundaries first, with types, interfaces, placeholder clients, events, and tests that make the intended system visible.

## Rule

Scaffolding should create structure, not hidden behavior. Avoid implementing workflow logic until the architecture review is complete.

The recurring MVP rule is: **stub the decentralization, never stub the predicate**. A local KMS service, local credential issuer, and admin key can be centralized for the MVP. The access predicate, revocation, veto, requester binding, and audit behavior should be represented from the first scaffold.

## Phase 1: Documentation Baseline

Files:

- `docs/software-architecture.md`
- `docs/clinical-history-tiers.md`
- `docs/adr/0001-record-access-grants.md`
- `docs/adr/0002-emergency-record-access.md`
- `docs/scaffolding-plan.md`
- `docs/claude/stellar-integrated-health-supply-plan.md`
- `docs/claude/access-broker-contract-design.md`
- `docs/claude/kms-lit-integration-spec.md`

Add next:

- `docs/local-development.md`
- `docs/data-model.md`
- `docs/security-model.md`
- `docs/kms-gate.md`

## Phase 2: Workspace Layout

Create target directories:

```text
apps/
  web/
  api-indexer/
  kms-gate/
packages/
  domain/
  crypto/
  storage/
  kms/
  stellar-client/
  wallet/
  test-fixtures/
e2e/
```

Decision needed before this phase:

- migrate the existing Next app from `src/` into `apps/web/` immediately, or keep `src/` temporarily and scaffold only new packages/services around it.

Recommendation:

- keep `src/` temporarily until the first architecture review is complete
- create `packages/`, `apps/api-indexer/`, and `apps/kms-gate/` first
- migrate the web app after the Docker workflow is defined

## Phase 3: TypeScript Domain Package

Create `packages/domain`.

Initial files:

```text
packages/domain/src/clinical-history.ts
packages/domain/src/identity.ts
packages/domain/src/access-broker.ts
packages/domain/src/kms.ts
packages/domain/src/emergency.ts
packages/domain/src/prescription.ts
packages/domain/src/supplychain.ts
packages/domain/src/reservation-privacy.ts
packages/domain/src/audit.ts
packages/domain/src/index.ts
```

Initial exports:

- `ClinicalHistoryTier`
- `RecordLocator`
- `RecordMeta`
- `EncryptedRecordRef`
- `RecordManifest`
- `AccessGrant`
- `EmergencyAccessGrant`
- `PresenceProof`
- `OfflineEmergencyCard`
- `DelayedOfflineAudit`
- `AuditEvent`
- `Credential`
- `CredentialProof`
- `KmsReleasePredicate`
- `ReleaseRequest`
- `Prescription`
- `InventoryUnit`
- `DispensationReceipt`
- `OpposingInterestAttestation`
- `ReservationPrivacyRef`
- `DrugClassCommitment`

No runtime dependency should be added unless necessary.

## Phase 4: TypeScript Service Interfaces

Create interface-only packages first.

`packages/storage`:

- `RecordStorageProvider`
- `RecordLocatorResolver`
- `MinioRecordStorageProvider` placeholder
- `IpfsRecordStorageProvider` placeholder
- `PhysicalDriveRecordLocator` placeholder

`packages/crypto`:

- `EnvelopeEncryptionService`
- `KeyWrappingService`
- `CommitmentService`
- `EmergencyCardSigner`
- `PresenceProofVerifier`
- `DelayedAuditSigner`
- `DrugClassCommitmentService`

`packages/kms`:

- `KmsGate`
- `LocalStubGate`
- `LitGate`
- `ReleasePredicateEvaluator`
- `BrokerStateReader`

`packages/stellar-client`:

- `IdentityContractClient`
- `AccessBrokerContractClient`
- `PrescriptionContractClient`
- `SupplychainContractClient`

`packages/wallet`:

- `WalletAdapter`
- `MockWalletAdapter`
- `FreighterWalletAdapter`
- `ServerTestSigner`

## Phase 5: API/Indexer Scaffold

Create `apps/api-indexer`.

Initial modules:

```text
apps/api-indexer/src/events/
apps/api-indexer/src/projections/
apps/api-indexer/src/workflows/
apps/api-indexer/src/storage/
apps/api-indexer/src/routes/
apps/api-indexer/src/notifications/
apps/api-indexer/src/seed/
```

Initial services:

- `EventIngestor`
- `ProjectionStore`
- `AccessGrantWorkflow`
- `EmergencyAccessWorkflow`
- `DelayedAuditWorkflow`
- `PatientNotificationWorkflow`
- `PrescriptionReservationWorkflow`
- `SeedDataService`

No web framework choice should be locked until dependencies are reviewed. If no new dependency is approved, start with Node's built-in HTTP server or Next API routes for the earliest scaffold.

## Phase 6: KMS Gate Scaffold

Create `apps/kms-gate`.

Initial modules:

```text
apps/kms-gate/src/routes/
apps/kms-gate/src/predicate/
apps/kms-gate/src/stellar/
apps/kms-gate/src/keys/
apps/kms-gate/src/test-vectors/
```

Initial services:

- `LocalStubGate`
- `BrokerStateReader`
- `ReleasePredicateEvaluator`
- `KeyReleaseService`
- `ConformanceTestRunner`

The KMS scaffold must include tests for the release predicate even before real encryption is implemented:

- no committed grant means deny
- wrong requester means deny
- revoked grant means deny
- vetoed grant means deny
- before `revealAt` means deny
- at or after `expiresAt` means deny
- valid in-window grant means allow

## Phase 7: Rust/Soroban Contract Scaffolds

Create contract directories:

```text
contracts/identity/
contracts/access-broker/
contracts/prescription/
contracts/supplychain/
contracts/incentive/
```

Each contract starts with:

```text
Cargo.toml
src/lib.rs
src/types.rs
src/storage.rs
src/events.rs
src/errors.rs
src/test.rs
```

Initial contract work:

- compile empty contract shells
- define storage keys
- define event structs/topics
- define public method signatures
- add tests that verify initialization and placeholder state

`contracts/access-broker` should scaffold these concepts first:

- `Tier`
- `GrantType`
- `RecordMeta`
- `Grant`
- `PresenceProof`
- `CredentialProof`
- `Capability`
- `request_access`
- `revoke`
- `veto`
- `submit_delayed_audit`

Access-broker tests should include a simulation-safety invariant: every public return type is non-secret and safe to expose before transaction submission.

All contracts should explicitly choose storage classes for each key. Temporary storage can clean up short-lived entries, but every security decision must still check explicit business timestamps such as `expires_at` and `reveal_at`.

Do not implement real cross-contract workflows until the contract boundaries are reviewed.

## Phase 8: Docker Baseline

Repository ownership note: keep this Docker baseline working in the monorepo,
but use [`docs/integration-workspace.md`](integration-workspace.md) as the
boundary for future component-owned CI. Contract reproducibility work should
remain contract-focused; it should not grow into a universal workspace flake
that carries web, service, KMS, and e2e toolchains together.

Create or update:

```text
docker-compose.yml
Dockerfile.web
Dockerfile.api-indexer
Dockerfile.kms-gate
Dockerfile.contract-runner
Dockerfile.e2e
docs/local-development.md
```

Target services:

- `web`
- `api-indexer`
- `kms-gate`
- `postgres`
- `minio`
- `stellar-local`
- `contract-runner`
- `verdaccio`
- `e2e`

Decision needed:

- exact local Stellar/Soroban image/tooling
- how `kms-gate` reads committed state in local tests

Resolved dependency-cache baseline:

- Verdaccio runs as the repository-owned `verdaccio` Docker Compose service.
- Locked mode uses `verdaccio-config.yaml` with no npmjs uplink.
- Approved package installs use `./unlock-npmjs.sh`, then `pnpm add`, then
  `./lock-npmjs.sh`.
- The Docker volume `verdaccio-storage` persists cached packages across
  container recreation.

## Phase 9: First Vertical Slice

After scaffolding compiles:

1. seed patient, clinician, institution, and credential issuer
2. store encrypted synthetic Tier 3 clinical record in MinIO
3. create patient grant metadata on local Soroban through `access-broker`
4. index grant event into Postgres
5. clinician requests access and receives non-secret capability
6. local KMS gate reads committed broker state and evaluates predicate
7. clinician retrieves ciphertext and decrypts synthetic record
8. clinician verifies commitment
9. read audit event is submitted

Only after this works should emergency break-glass implementation begin.

## Phase 10: Emergency Vertical Slice

After Tier 3 grant flow works:

1. seed responder and institution credentials
2. create Tier 2 emergency bundle commitment
3. register patient emergency token/card public key
4. open break-glass grant with presence proof
5. notify patient during veto window
6. verify veto blocks key release
7. verify no veto allows key release after `revealAt`
8. submit delayed offline audit for a Tier 1 card read

## Phase 11: Prescription and Supply-Chain Vertical Slice

After access-broker/KMS/emergency flows work:

1. seed pharmacy, drug product, batch, and inventory unit
2. issue encrypted prescription event to patient record
3. create pseudonymous prescription commitment
4. create fresh reservation privacy reference
5. reserve eligible in-spec inventory
6. verify quarantine prevents reservation
7. dispense with pharmacy credential and patient active co-signature
8. write encrypted dispensation receipt commitment back to Tier 3
9. record opposing-interest attestation for custody/dispense proof where modeled

## Non-Goals During Scaffolding

- no production encryption claims
- no full HIPAA compliance claims
- no mainnet deployment
- no speculative token mechanics
- no real patient data
- no dependency sprawl
- no UI redesign beyond what is needed to expose the scaffolded flows
- no Lit Protocol integration until the local KMS predicate is tested
- no incentives or payments until the core loop is proven

## Review Checklist

Before implementation:

- architecture reviewed
- clinical history tiers reviewed
- access broker model accepted
- KMS gate predicate accepted
- storage backend selected for MVP
- credential model selected for MVP
- emergency veto-window behavior accepted
- offline-card audit/budget behavior accepted
- reservation privacy level accepted
- Soroban storage class and renewal strategy accepted
- local chain strategy selected
- package/workspace migration plan selected
- Docker baseline accepted
