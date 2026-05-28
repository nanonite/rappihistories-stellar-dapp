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
