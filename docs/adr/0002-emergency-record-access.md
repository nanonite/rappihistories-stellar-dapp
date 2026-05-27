# ADR 0002: Emergency Record Access Uses Limited-Scope Break-Glass Grants

## Status

Proposed.

## Context

The normal records flow assumes the patient is conscious and can approve a clinician or institution's access request. That fails in emergency care. If a patient is unconscious after an accident, a doctor or paramedic may need immediate access to critical clinical history: allergies, medications, conditions, implants, blood type, emergency contacts, and recent diagnoses.

The system needs a limited emergency path without turning patient-controlled records into a permanently open database. Later review refined this into three related controls: Tier 1 offline card, Tier 2 network-only break-glass bundle, and a consent veto window before non-critical Tier 2 key release.

## Decision

The protocol should support limited-scope emergency access, also called a break-glass grant.

Emergency access should not expose the patient's full clinical history by default. It should expose only an emergency profile or patient-approved emergency record bundle. The emergency bundle can include records such as:

- allergies
- active medications
- major diagnoses and conditions
- implanted devices
- blood type, where available
- emergency contacts
- recent high-risk procedures or care notes
- care directives, where legally valid

Two emergency authorization models are acceptable for MVP exploration:

1. Patient pre-authorizes an institution, emergency network, or credentialed responder role to access the emergency bundle when necessary.
2. Patient creates an emergency read token or emergency access capability that can be presented by a qualified responder under defined conditions.
3. Patient carries a physical credential, such as a driver's license, medical ID card, bracelet, or phone wallet pass, with QR/NFC data that points responders to the emergency bundle access flow.

In these models, the emergency grant must be limited by scope, time, credential requirements, and KMS key-release rules.

Tier 2 emergency bundle access is network-only. The access broker records the emergency grant and audit event, but the KMS releases the decryption key only after committed grant state satisfies the release predicate.

A short consent veto window should sit between emergency grant creation and non-critical key release. If the patient is conscious and vetoes inside the window, the KMS must never release that key. If the patient is unconscious and no veto arrives, the read proceeds after the window. The most critical, least-stigmatizing micro-subset, such as severe allergies, anticoagulants, and implanted devices, can use a zero-second window.

If a patient token/card is absent, bricked, or unreadable, the protocol should support a tokenless fallback for a vital subset only. The fallback requires heavier proof, such as institution plus second-clinician co-signature, and a distinct audit topic for monitoring.

The tokenless fallback should not require biometric identity or a nation-state identity registry. A patient may opt out of carrying a token/card; the consequence is narrower and more heavily audited access, not denial of emergency care.

## Minimum Controls

Emergency access must include these controls:

- access is limited to an emergency bundle, not the entire record
- responder or institution credential is checked before access
- presence proof is used when available
- tokenless fallback is vital-subset only and requires stronger co-signature
- non-critical emergency key release observes a veto window
- grant event is written to the audit trail
- offline access events are queued and written to the audit trail when network access returns
- patient is notified after access when possible
- access reason or emergency attestation is recorded
- grant expires quickly unless explicitly extended
- all emergency reads are reviewable by the patient or patient representative
- abuse can be escalated to the institution, regulator, or credential issuer

The on-chain event should record emergency access metadata only:

- patient pseudonym or emergency record identifier
- responder, clinician, or institution identifier
- credential reference
- timestamp
- emergency scope
- expiration
- emergency attestation or reason code
- reveal time for veto-windowed access
- content hash, CID, or commitment for the emergency bundle

The on-chain event must not include diagnosis details, accident details, location-sensitive medical facts, or human-readable PHI.

## Implications

This adds a second consent path: normal patient-driven grants and emergency break-glass grants. The product must make that distinction clear.

Emergency access improves clinical usefulness, but it creates a sensitive abuse path. The design should assume emergency access will be audited after the fact, not silently trusted.

The emergency bundle should be separately encrypted from the full record. That allows the patient to expose a smaller, safer data set in emergencies without sharing the main clinical history key.

Tier 2 access depends on the access broker plus KMS gate. The broker returns non-secret locator and commitment data. The KMS releases a key only against committed, current, unrevoked, un-vetoed, in-window grant state.

An NFC or QR-enabled physical credential should not store the full emergency clinical history in cleartext. It should store a pointer, token, or capability that lets a responder request or unlock the limited emergency bundle. If offline emergency access is required, the locally stored data must still be minimal, separately encrypted where possible, and treated as a deliberate trade-off against privacy.

Offline emergency access is acceptable only if the responder device or emergency access app creates a signed local audit record at read time and queues it for submission when network access returns. The queued audit should include the responder or institution identifier when available, credential proof or local credential reference, timestamp from the reading device, emergency scope, and credential/card identifier. The system should mark delayed audits distinctly so patients and reviewers can see that the access happened offline before it was posted.

The MVP can demonstrate this without solving every legal jurisdiction. It can show a patient configuring an emergency profile, a credentialed responder opening it under an emergency flow, a conscious patient vetoing a pending read, an unconscious-patient read proceeding after the window, and immutable audit entries appearing afterward.

## Open Questions

- Who can issue emergency responder or institution credentials in the MVP?
- Should emergency access require one responder, two responders, or institution-level approval?
- Should the patient carry an emergency QR/NFC token, have access discoverable through identity lookup, or support both?
- What data, if any, should be readable from a physical credential without network access?
- What device/app is trusted to queue and later submit offline emergency-read audit events?
- What exact fields belong in the emergency bundle?
- What exact fields belong to the instant critical subset versus the veto-windowed bundle?
- How should post-access patient notification work?
- What is the abuse review workflow?
