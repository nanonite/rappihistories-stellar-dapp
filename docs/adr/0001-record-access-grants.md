# ADR 0001: Record Access Grants Use Off-Chain Payloads and On-Chain Audit Metadata

## Status

Accepted for MVP direction.

## Context

The MVP needs a patient to grant a new clinician access to clinical history without placing protected health information directly on Stellar. The clinician must be able to retrieve and read the record, while the system keeps a durable audit trail showing that access was granted, when it was granted, and to which clinician or institution.

The clinical record payload may live in S3-compatible storage, IPFS, a physical encrypted drive, a user-controlled filesystem, or another patient-approved storage backend. Stellar/Soroban should verify and audit access events, not become the medical record database.

Later review refined the model: the on-chain contract is an access broker, not a key vault. It returns non-secret capability metadata. A separate KMS gate releases or re-wraps decryption keys only after checking committed, current grant state.

## Decision

When a patient grants record access, the access broker records grant metadata and can return non-secret capability data: grant identifier, off-chain locator, and content commitment. The requesting clinician receives the storage location, but not a usable decryption key from the blockchain.

A separate KMS gate releases or re-wraps the cryptographic material needed for read capability only if current committed broker state satisfies the release predicate:

- committed grant exists
- requester matches the caller
- grant is not revoked
- grant is not vetoed, where applicable
- reveal time has passed, where applicable
- grant has not expired

The access broker's return values must be safe to expose during Soroban simulation/preflight. The broker may return locator, commitment, and grant identifier, but never a decryption key, wrapped key, bearer secret, or PHI.

The blockchain write records the access event metadata only:

- patient pseudonym or patient record identifier
- clinician and/or institution identifier
- credential reference for the requesting clinician or institution
- grant timestamp
- reveal time, where applicable
- grant scope
- expiration time, if applicable
- content hash, CID, or commitment for integrity verification
- grant status, such as active, revoked, vetoed, or expired

The blockchain write must not include raw clinical content, patient name, diagnosis, notes, medications, demographic details, or any other human-readable PHI.

For the MVP, access can be modeled as a grant-specific encrypted envelope:

1. The clinical record is encrypted off-chain with a data key.
2. The patient authorizes a clinician by creating a scoped grant on the access broker.
3. The clinician receives the non-secret locator and commitment.
4. The contract records the grant metadata and emits an audit event.
5. The clinician asks the KMS gate for key release.
6. The KMS gate re-reads committed broker state and releases only if the predicate passes.
7. The clinician retrieves the encrypted payload and verifies its hash, CID, or commitment against the on-chain metadata.

## Implications

This keeps Stellar in the role it is strongest for in this MVP: authorization state, auditability, integrity commitments, and workflow coordination. It avoids turning the chain into a PHI store.

The storage backend remains replaceable. S3-compatible storage, IPFS, Filecoin-backed IPFS, a physical encrypted drive, or a user-selected filesystem can all fit this model if they can produce a verifiable content identifier or commitment and expose the encrypted payload through a retrievable location or transfer workflow.

The implementation should define a storage-agnostic record locator interface. The interface represents where the encrypted payload rests and how an authorized reader can retrieve it, without assuming that the location is always a cloud URL. A locator may be an HTTP URL, S3 object key, IPFS CID, removable-drive path, institutional document reference, or another resolvable pointer.

Revocation has a hard limit: it can stop future key releases, rotate keys for future versions, and mark the grant revoked on-chain, but it cannot make a clinician forget or delete a record they already downloaded. The product and compliance model must present revocation honestly.

The MVP may use a single local KMS service. That is a documented central trust point, not the final decentralization story. The release predicate itself must be real from day one; only decentralization of the key-release service is stubbed.

Grant metadata itself can still create linkage risk. The implementation should use pseudonymous identifiers and avoid public metadata that reveals patient identity, diagnosis, location, or sensitive record category unless Roger explicitly approves that trade-off after review.

## Open Questions

- Which storage backend should the MVP use first: local object storage, S3-compatible MinIO, IPFS, physical encrypted drive simulation, or another option?
- Should grant metadata be public, contract-readable only through an indexer policy, or encrypted/commitment-based where possible?
- What credential system identifies clinicians and institutions in the MVP?
- How will key recovery work if the patient loses wallet or encryption credentials?
- What is the minimum useful grant scope model for the demo: full record, record category, single document, or time-bounded session?
- What is the exact local KMS trust boundary for the MVP?
