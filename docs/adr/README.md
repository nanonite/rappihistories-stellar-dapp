# Architecture Decision Records

This directory stores decisions that affect architecture, privacy, compliance posture, data custody, blockchain boundaries, or long-term implementation direction.

## Current ADRs

- [ADR 0001: Record Access Grants Use Off-Chain Payloads and On-Chain Audit Metadata](0001-record-access-grants.md)
- [ADR 0002: Emergency Record Access Uses Limited-Scope Break-Glass Grants](0002-emergency-record-access.md)

## Status Values

- `Proposed`: under discussion and not yet final
- `Accepted for MVP direction`: approved as the current MVP approach
- `Superseded`: replaced by a later ADR
- `Rejected`: documented but not selected

## ADR Requirements

Each ADR should describe:

- context
- decision
- implications
- open questions

If a decision affects PHI, patient identity, emergency access, contract storage, key management, prescription reservations, inventory custody, or cross-chain/storage integration, it belongs here before implementation locks it in.
