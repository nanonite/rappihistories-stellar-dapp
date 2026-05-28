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
- Stellar latest-ledger helper
- KMS release route validation for malformed requests

Browser automation should sit above this layer as UX confirmation only. Product
correctness should be proven here through service APIs and Stellar helpers.
