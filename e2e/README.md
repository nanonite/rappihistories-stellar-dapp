# E2E Functional Tests

The first e2e layer is API-first. It runs inside the Docker Compose network and
talks directly to `api-indexer`, `kms-gate`, `stellar-local`, and the shared
contract bootstrap volume.

Run it with:

```bash
docker compose -f e2e/docker-compose.yml --profile test run --rm e2e-runner
```

The runner uses the `node:22-bookworm` image and Node's built-in test runner.
No npm install is required for the functional harness.

Current coverage:

- service health for `api-indexer`, `kms-gate`, and Stellar RPC
- `/shared/contract-ids.json` shape
- `/shared/seed-identities.json` role counts and unique funded identities
- api-indexer read route availability for seeded patients
- api-indexer REST response hygiene: camelCase payloads and no raw event leakage
- api-indexer cursor state coverage for indexed grant ledgers
- Stellar latest-ledger helper
- KMS release route validation for malformed requests
- Tier 3 setup through signed Soroban transactions on `stellar-local`
- api-indexer read-model ingestion from access-broker contract events
- Tier 3 happy path key release through api-indexer-backed KMS grant lookup
- Tier 3 revoked and expired grant denials through the live KMS predicate
- break-glass veto denial through signed Stellar contract state and KMS `VETOED`
- break-glass no-veto release after `revealAt`
- tokenless fallback release after an indexed emergency cosigner grant
- prescription bridge from clinician issue to patient pharmacy selection,
  supplychain reservation, dispense, and dispensation receipt writeback
- prescription negative paths: pharmacy-only dispense denial and quarantined
  batch reservation denial
- KMS predicate conformance table against live local services, including
  no-grant, wrong-requester, revoked, vetoed, before-reveal, expired, allowed,
  revoked-and-vetoed ordering, and simulated no-send grant defense

Browser automation should sit above this layer as UX confirmation only. Product
correctness should be proven here through service APIs and Stellar helpers.

## Manual Browser Conformance Demo

Run the local manual demo with:

```bash
./e2e/manual-demo.sh
```

Then open:

```text
http://127.0.0.1:3001/manual-e2e
```

The page is enabled only when `MANUAL_E2E_ENABLED=1` and reads the local
`contract-shared` Docker volume through the web server. This is a read-only
operator dashboard over pre-seeded local scenario state. It calls live
`api-indexer` and `kms-gate`, but it does not yet drive patient, clinician, or
pharmacy browser actions.

It shows:

- Tier 1 offline emergency-card posture
- Tier 2 break-glass veto, no-veto reveal, and tokenless fallback
- Tier 3 record commitment, clinician grant, KMS release, revoke, and expiry
- Tier 3 prescription bridge from issue to pharmacy dispense and receipt
  writeback

MinIO is part of the local Docker network, but this page does not yet fetch
ciphertext from MinIO or decrypt/display plaintext. The interactive Tier 3
browser flow with MinIO ciphertext retrieval is tracked separately.

Use the **Refresh checks** button after the stack starts. If scenario files are
still pending, wait a few seconds and refresh again.

By default, `manual-demo.sh` resets the e2e Docker volumes before booting so the
contract seed files, Postgres read model, and local Stellar ledger start from the
same clean scenario. To keep existing local state, run:

```bash
MANUAL_E2E_PRESERVE_STATE=1 ./e2e/manual-demo.sh
```

Useful local endpoints:

```text
http://127.0.0.1:8788/v1/health
http://127.0.0.1:8790/v1/health
```

To reset stale local state:

```bash
docker compose -f e2e/docker-compose.yml --profile test down -v
./e2e/manual-demo.sh
```
