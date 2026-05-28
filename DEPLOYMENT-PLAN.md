# Deployment Plan

Production deployment is more than deploying the smart contracts and hosting the
dApp. Stellar provides the blockchain execution layer, but the MVP still needs
off-chain services for indexing, encrypted storage, key release, operations, and
the web experience.

## Production Shape

### 1. Deploy Soroban Contracts

Deploy the five MVP contracts to the selected Stellar network:

- `identity`
- `access-broker`
- `prescription`
- `supplychain`
- `incentive`

After deployment:

- Save contract IDs in a production configuration source.
- Decide which account controls initialization/admin actions.
- Decide upgrade/admin key custody before mainnet use.
- Treat contract IDs as durable integration inputs for the dApp, indexer, and
  KMS gate.

### 2. Deploy the dApp Frontend

Deploy the web app to a web host and configure:

- Stellar network name.
- RPC URL.
- Horizon URL if classic account or asset reads are needed.
- Contract IDs.
- Wallet support.
- Environment-specific feature flags.

The frontend should request user signatures through wallet, passkey, or account
abstraction flows. It should not hold long-lived admin secrets.

### 3. Run Off-Chain Services

Production needs these runtime services:

- `api-indexer`: watches Stellar contract events and builds queryable Postgres
  read models.
- `kms-gate`: evaluates access grants and requester authentication before key
  release.
- Postgres: indexed state, app state, operational state, and query surfaces.
- Object storage: encrypted clinical records, prescription payloads,
  dispensation receipts, and attachments.

The local e2e Compose stack is a production-shaped rehearsal of these pieces:
local Stellar, local object storage, local database, contract runner, indexer,
KMS gate, and web app.

### 4. KMS And Encrypted Data Boundary

KMS is the most important missing production primitive.

Clinical content should remain encrypted off-chain. Stellar should store only
grants, commitments, hashes, pointers, audit facts, and supply-chain facts.

The KMS path should:

- Hold or wrap per-record/per-bundle data keys.
- Authenticate the requester.
- Read or verify relevant Stellar state.
- Evaluate the release predicate.
- Release only the specific key material permitted by the grant.
- Log release attempts and outcomes.

`kms-gate` is the policy service around the KMS. The actual production KMS could
be a cloud KMS, HSM-backed service, or another managed key system, but the
release boundary must stay explicit.

## What Stellar Handles

Stellar handles:

- Accounts.
- Signatures.
- Transaction ordering.
- Ledger finality.
- Soroban contract execution.
- On-chain token/account primitives.

## What Stellar Does Not Handle

The application must still handle:

- Real-world identity verification.
- Clinician credentialing.
- Encrypted PHI storage.
- KMS policy and key recovery.
- Frontend hosting.
- Database indexing.
- Secrets management.
- Backups.
- Monitoring and alerting.
- Compliance posture and operational controls.

## MVP Deployment Checklist

1. Build and test contracts.
2. Deploy contracts to the target network.
3. Store contract IDs in environment/config.
4. Deploy the web app.
5. Deploy Postgres and object storage.
6. Deploy `api-indexer` with RPC URL and contract IDs.
7. Deploy `kms-gate` with access to KMS and Stellar RPC.
8. Configure wallet/network settings.
9. Run smoke tests for the closed loop:
   - patient grants access
   - clinician reads encrypted record through KMS path
   - clinician writes update
   - clinician issues prescription
   - inventory is reserved
   - pharmacy dispenses
   - dispensation writes back to patient record
10. Add monitoring, backups, and operational runbooks before real users.

## Practical Summary

Production is:

```text
Stellar contracts
+ hosted dApp
+ RPC provider
+ encrypted object storage
+ KMS gate
+ indexer
+ Postgres
+ operations/security
```

The blockchain gives the shared execution and audit substrate. The healthcare
product still depends on careful off-chain custody, key release, and operational
security.
