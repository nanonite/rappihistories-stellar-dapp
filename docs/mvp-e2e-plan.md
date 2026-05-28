# MVP E2E Plan

This plan keeps the MVP moving from local integration to Testnet without adding
external network noise before the core product loop is proven.

## Goal

Prove one narrow vertical slice first:

```text
patient stores encrypted Tier 3 record
-> broker records commitment and locator
-> patient grants clinician access
-> clinician requests KMS release
-> clinician decrypts and verifies commitment
-> patient revokes access
-> KMS denies with REVOKED
```

This is the minimum useful e2e because it exercises the contracts, storage,
KMS predicate, indexer/read model, wallet or mock signing boundary, and web flow
as one system.

## Phase 1: Local Runtime

Complete these root integration tasks first:

1. `INF-3` / Chainlink `#4`: expand Docker Compose with all local services.
   Required services: `verdaccio`, `web`, `api-indexer`, `kms-gate`,
   `postgres`, `minio`, `stellar-local`, and `contract-runner`.

2. `INF-5` / Chainlink `#6`: add the contract deployment and seed runner.
   The runner should deploy all MVP contracts to `stellar-local`, write
   `/shared/contract-ids.json`, and seed admin, patient, clinician, pharmacy,
   and responder accounts.

These two tasks create the environment where the rest of the e2e work can run
without depending on Stellar Testnet availability, funding, or RPC behavior.

### Local Service Interface

The local e2e stack has three explicit service boundaries:

1. `contract-runner` is the bootstrap writer. It deploys the Soroban contracts
   to `stellar-local`, seeds local identities, and writes shared runtime files.

2. `api-indexer` is the read-model owner. It follows Stellar RPC events for the
   deployed contracts, persists queryable state in Postgres, and exposes REST
   routes for the web app and local tests.

3. `kms-gate` is the release decision boundary. It receives release requests,
   checks the grant predicate, and returns wrapped key material only when the
   local policy allows it.

The `contract-shared` Docker volume is the bootstrap handoff between these
services. It is writable only by `contract-runner` and mounted read-only by
`api-indexer` and `kms-gate`.

`/shared/contract-ids.json`:

```json
{
  "identity": "C...",
  "accessBroker": "C...",
  "prescription": "C...",
  "supplychain": "C...",
  "incentive": "C..."
}
```

`/shared/seed-identities.json`:

```json
{
  "identities": [
    { "alias": "admin", "role": "admin", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "patient-1", "role": "patient", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "patient-2", "role": "patient", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "clinician-1", "role": "clinician", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "clinician-2", "role": "clinician", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "pharmacy", "role": "pharmacy", "publicKey": "G...", "secretKey": "S..." },
    { "alias": "responder", "role": "responder", "publicKey": "G...", "secretKey": "S..." }
  ]
}
```

`api-indexer` local HTTP interface:

- `GET /v1/health` returns `{ "ok": true }`.
- `GET /v1/grants?patient=<patientPseudonym>` returns active grants.
- `GET /v1/audit?patient=<patientPseudonym>` returns audit events.
- `GET /v1/notifications?patient=<patientPseudonym>` returns notifications.
- `GET /v1/records?patient=<patientPseudonym>` returns records.

`kms-gate` local HTTP interface:

- `GET /v1/health` returns `{ "ok": true }`.
- `POST /v1/release` accepts `{ grantId, requester, requesterAuth, locator }`.
  It returns `{ wrappedKey }` when allowed, or `{ denied: true, reason }` when
  the predicate, auth, or rate limit denies the request.

The current `kms-gate` container reads grants from `api-indexer` for the Tier 3
path and verifies requester signatures using the seeded local Stellar
identities.

## Phase 2: Minimum E2E

After the local runtime starts reliably:

1. `E2E-1` / Chainlink `#51`: add API-first functional e2e infrastructure.
   Tests should drive service APIs and Stellar helpers directly for setup,
   actions, and assertions. This keeps the product spine deterministic and
   avoids making functional correctness depend on browser automation.

   Run the functional harness with:

   ```bash
   docker compose -f e2e/docker-compose.yml --profile test run --rm e2e-runner
   ```

2. Add Playwright and mock wallet infrastructure only for UX confirmation.
   Configure browser tests against `http://web:3000`, inject the mock wallet
   adapter, and verify that the user-facing screens reflect the already-proven
   API flow.

3. `E2E-2` / Chainlink `#52`: implement the Tier 3 happy path, revocation,
   and expiry checks.

   The current local version uses signed Soroban transactions against
   `stellar-local` for record registration, grant creation, and revocation.
   `api-indexer` builds the read model from contract events, and `kms-gate`
   performs release decisions through that indexed state.

This phase is the MVP spine. Once it passes locally, the system has crossed from
component completeness into working product integration.

## Phase 3: Local Hardening

Add edge cases in increasing complexity:

1. Tier 3 security branches:
   `EXPIRED`, `WRONG_REQUESTER`, `NO_GRANT`, and commitment mismatch before
   display.

2. Api-indexer confidence:
   REST route shape, camelCase responses, no raw event leakage, notification
   payload hygiene, and `_indexer_state.last_ledger` resume behavior.

3. Break-glass:
   patient veto, no-veto reveal, and tokenless fallback with dual co-sign.

4. Prescription bridge:
   clinician update, prescription issue, inventory reservation, pharmacy
   dispense with patient co-sign, and dispensation receipt writeback.

5. Supply-chain failure cases:
   quarantined inventory cannot reserve, double reservation fails, and
   pharmacy-only dispense fails.

6. Full KMS conformance:
   run the predicate truth table against both the pure domain predicate and
   the live KMS HTTP endpoint.

## Phase 4: Stellar Testnet

Move to Stellar Testnet only after the local minimum e2e passes.

Create a dedicated Testnet deployment task that:

- deploys the MVP contracts to Stellar Testnet
- records Testnet contract IDs and network configuration
- funds test accounts with Friendbot
- verifies Freighter signing against real Testnet accounts
- runs a manual or scripted smoke flow for the same Tier 3 spine

Do not start with broad Testnet automation. First prove the same minimal spine:
record commitment, grant, KMS release, read, revoke, and `REVOKED` denial.

## Rule Of Thumb

Local e2e answers: "Does our system work?"

Testnet smoke answers: "Does our working system survive the real Stellar
network boundary?"

Keep those questions separate until the local spine is green.
