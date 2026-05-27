# Clinical History Access Tiers

## Purpose

This is a research/design note for the MVP data model. It defines three practical tiers of clinical history access so the product can support normal patient-controlled sharing, emergency break-glass access, and offline emergency reads without treating all medical data the same way.

This note incorporates the later adversarial-review feedback from `docs/claude/`: the tier boundary must be real, Tier 2 is network-only, emergency reads need a consent veto window, key release is separate from authorization, and offline reads are an explicit availability-over-auditability trade-off.

This is not medical, legal, or regulatory advice. Final clinical content and compliance posture should be reviewed with qualified healthcare and legal advisors before a pilot.

## Design Principle

Clinical history should be split by urgency, sensitivity, and access conditions.

The system should not expose a full longitudinal health record when a smaller emergency subset is enough. It should also not make emergency responders wait for full patient consent when the patient is unconscious and immediate care depends on critical facts.

The tier boundary is real in design and code. Each tier is a distinct object with its own commitment, verification rule, storage treatment, key-release behavior, and audit mode. It should not be implemented as one giant patient record with sections hidden in the UI.

The three tiers are:

1. **Offline Emergency Card**: tiny, non-stigmatizing, immediately readable from NFC/QR/physical credential.
2. **Online Emergency Bundle**: limited emergency record available through network-only break-glass access.
3. **Full Clinical History**: patient-controlled longitudinal record shared through normal scoped consent.

## Tier 1: Offline Emergency Card

### Purpose

Give paramedics or emergency clinicians enough information to avoid immediate harm when there is no network access or the patient is unconscious.

This tier is the highest availability and lowest privacy tier. It should be intentionally small and non-stigmatizing by design, because a leak is possible whenever data is readable offline.

### Access Pattern

- Readable from NFC, QR, phone wallet pass, medical ID card, bracelet, or driver's-license-style credential.
- Can be read without network access if the patient opted into that trade-off.
- Contains either minimal cleartext emergency facts, a signed emergency pointer, or both.
- Does not use the access broker for the offline read itself; the card payload must be self-verifying.
- Read event should be logged locally by the responder device/app and submitted to the audit trail when network access returns.
- Offline reads should consume a finite signed budget or counter where practical, forcing periodic resync and limiting blast radius.
- The patient's own card/app should surface evidence of offline reads when possible, independent of delayed responder submission.

### Data Format

Use a compact emergency summary document. It can be represented as JSON for the MVP and mapped to FHIR-compatible resources later.

Recommended fields:

```json
{
  "tier": "offline_emergency_card",
  "schemaVersion": "0.2",
  "cardId": "emcard_abc123",
  "patientDisplay": {
    "preferredName": "Optional",
    "yearOfBirth": "Optional",
    "photoHash": "Optional"
  },
  "criticalAlerts": [
    {
      "type": "allergy",
      "label": "Penicillin",
      "severity": "severe",
      "reaction": "Anaphylaxis"
    }
  ],
  "criticalMedications": [
    {
      "name": "Warfarin",
      "reason": "Anticoagulant",
      "lastVerified": "2026-05-26"
    }
  ],
  "majorConditions": [
    {
      "label": "Type 1 diabetes",
      "clinicalStatus": "active"
    }
  ],
  "implantedDevices": [
    {
      "label": "Pacemaker",
      "manufacturer": "Optional",
      "model": "Optional"
    }
  ],
  "careDirectives": {
    "hasDirective": true,
    "summary": "Optional short text",
    "onlineReferenceAvailable": true
  },
  "emergencyContacts": [
    {
      "name": "Optional",
      "relationship": "Optional",
      "phone": "Optional"
    }
  ],
  "onlineEmergencyPointer": {
    "locatorType": "url_or_cid_or_registry_pointer",
    "locator": "Optional pointer to Tier 2",
    "commitment": "hash-or-commitment"
  },
  "offlineAudit": {
    "budgetId": "offline_budget_abc123",
    "remainingReadsHint": "Optional",
    "auditSubmitEndpoint": "Optional"
  },
  "lastUpdated": "2026-05-26",
  "signature": "issuer-or-patient-signature"
}
```

### Belongs Here

- life-threatening allergies
- critical active medications, especially anticoagulants, insulin, seizure medication, transplant medication, or other high-risk drugs
- major active conditions relevant to emergency care
- implanted medical devices
- emergency contacts
- care directive flag or short directive summary
- pointer to the online emergency bundle

### Does Not Belong Here

- full diagnosis history
- detailed clinical notes
- lab history
- imaging files
- behavioral health notes
- reproductive or sexual health history
- substance-use treatment history
- full medication history
- insurance/payment data
- broad demographic profile

## Tier 2: Online Emergency Bundle

### Purpose

Give credentialed emergency responders a richer but still limited clinical picture when the patient cannot consent and network access is available.

This tier is for break-glass access. It is broader than the offline card, but still not the full record. It is network-only because the safety properties depend on committed grant state, veto/revocation checks, and KMS key release.

### Access Pattern

- Accessed through QR/NFC pointer, patient identity lookup, emergency registry lookup, or institution workflow.
- Requires responder, clinician, or institution credential.
- Requires emergency attestation or reason code.
- Prefers proof of patient presence through a tapped card/token when available.
- If the token is absent, lost, or failed, supports a tokenless fallback: institution plus second-clinician co-sign, vital subset only, and heavier audit.
- Creates an emergency grant on the access broker with `revealAt`, `expiresAt`, `revoked`, and `vetoed` state.
- Gives a conscious patient a short veto window before the fuller emergency key is released.
- Uses a criticality-graduated window: the most time-critical, least-stigmatizing micro-subset can be instant; the fuller emergency payload waits for the veto window.
- The KMS releases the decryption key only after the grant is committed, unrevoked, un-vetoed, in-window, and bound to the requester.
- Writes an audit event immediately when online.
- Patient or representative is notified afterward when possible.

### Data Format

Use an encrypted emergency bundle document. The chain stores only metadata, access state, and integrity commitment.

Recommended payload envelope:

```json
{
  "tier": "online_emergency_bundle",
  "schemaVersion": "0.2",
  "bundleId": "embundle_abc123",
  "patientPseudonym": "patient_pseudo_...",
  "sections": {
    "criticalInstantSubset": [],
    "allergies": [],
    "activeMedications": [],
    "majorConditions": [],
    "recentProcedures": [],
    "implantedDevices": [],
    "recentEncounters": [],
    "keyLabSignals": [],
    "careDirectives": [],
    "emergencyContacts": [],
    "emergencyFlaggedNotes": []
  },
  "sourceRecordCommitments": [
    {
      "recordId": "record_...",
      "commitment": "hash-or-commitment"
    }
  ],
  "lastVerifiedByPatient": "2026-05-26",
  "lastUpdated": "2026-05-26"
}
```

Recommended on-chain/access metadata:

```json
{
  "grantType": "emergency_break_glass",
  "patientPseudonym": "patient_pseudo_...",
  "bundleCommitment": "hash-or-commitment",
  "requesterRef": "responder_or_clinician_ref",
  "requesterCredentialRef": "credential_...",
  "institutionRef": "institution_...",
  "presenceProofRef": "optional_presence_proof_ref",
  "reasonCode": "unconscious_patient",
  "scope": "emergency_bundle",
  "openedAt": "2026-05-26T12:00:00Z",
  "revealAt": "2026-05-26T12:00:30Z",
  "expiresAt": "2026-05-26T18:00:00Z",
  "revoked": false,
  "vetoed": false,
  "auditMode": "online"
}
```

### Belongs Here

- all Tier 1 data
- fuller allergy details
- active medication list with dosage where clinically necessary
- major active and chronic conditions
- relevant recent encounters
- recent high-risk procedures
- implanted devices and device details
- selected critical labs or observations
- care directives and emergency contacts
- limited recent notes specifically marked emergency-relevant

### Does Not Belong Here

- full longitudinal record
- broad historical notes unrelated to emergency care
- sensitive categories unless explicitly emergency-relevant and patient-approved
- raw document archive
- payment and insurance records
- supply-chain or prescription reservation history unless directly relevant to current medication safety

## Tier 3: Full Clinical History

### Purpose

Support normal patient-controlled care continuity when the patient grants a clinician or institution access to their longitudinal record.

This is the most complete and most sensitive tier. It should require normal consent, explicit scope, and clear patient understanding.

### Access Pattern

- Patient grants access to a clinician, institution, or care team.
- Grant can be scoped by time, purpose, record category, document, or episode of care.
- Clinician receives non-secret capability metadata from the access broker: locator, commitment, and grant identifier.
- The KMS releases the decryption key only after it verifies committed, current, unexpired, unrevoked grant state.
- Contract records grant metadata and audit event.
- Revocation stops future key releases and rotates keys for future versions, but cannot undo data already retrieved.
- Sensitive categories require explicit per-category confirmation; a generic full-history grant should not silently include them.

### Data Format

Use encrypted record documents and a manifest. The manifest gives the authorized clinician a navigable index without exposing clinical content on-chain.

Recommended manifest:

```json
{
  "tier": "full_clinical_history",
  "schemaVersion": "0.2",
  "patientPseudonym": "patient_pseudo_...",
  "manifestId": "manifest_abc123",
  "records": [
    {
      "recordId": "record_001",
      "category": "allergy",
      "sensitive": false,
      "title": "Allergy list",
      "dateRange": {
        "from": "2020-01-01",
        "to": "2026-05-26"
      },
      "locator": {
        "type": "s3_object_or_ipfs_cid_or_drive_path",
        "value": "encrypted-record-location"
      },
      "commitment": "hash-or-commitment",
      "encryption": {
        "algorithm": "TBD",
        "wrappedKeyRef": "kms_grant_key_ref"
      }
    }
  ],
  "grant": {
    "scope": "category_or_document_or_full",
    "purpose": "treatment",
    "grantee": "clinician_or_institution_ref",
    "expiresAt": "2026-06-26T00:00:00Z"
  }
}
```

### Belongs Here

- diagnoses and problem list
- allergies and intolerances
- medication history
- immunizations
- procedures
- encounters and visit summaries
- lab results and observations
- imaging reports and document references
- care plans
- clinician notes, where authorized
- prescriptions and dispensation receipts
- provenance and source system references

### Does Not Belong Here by Default

Some data should require extra patient confirmation or special handling even inside full-history sharing:

- behavioral health records
- substance-use treatment records
- reproductive and sexual health records
- genetic data
- minors' records and guardianship-sensitive records
- legal/court-related medical documents
- data shared under special jurisdictional restrictions

## Cross-Tier Rules

### Storage

All tiers can use the same storage-agnostic locator model:

```json
{
  "locatorType": "url | s3 | ipfs | filecoin | removable_drive | institutional_reference | other",
  "locatorValue": "opaque-location-value",
  "contentCommitment": "hash-or-commitment",
  "encryptionProfile": "none | local_minimal | encrypted_envelope",
  "retrievalInstructions": "optional human or app-readable instructions"
}
```

Tier 1 may include minimal cleartext if the patient accepts offline-read privacy trade-offs. Tier 2 and Tier 3 should be encrypted by default.

### Authorization and Key Release

Authorization and key release are separate gates.

- The access broker stores commitments, locators, grant state, revocation/veto state, and audit events.
- The KMS or KMS stub holds the ability to release or re-wrap data keys.
- The encrypted store serves ciphertext only.
- A usable key is released only if current committed broker state satisfies the release predicate.

The MVP may stub decentralization with a single KMS service, but it must not stub the predicate. Simulation-only grants, revoked grants, vetoed grants, expired grants, or grants for a different requester must not release keys.

### Audit

Every read should create or eventually create an audit event.

Online audit:

```json
{
  "eventType": "record_read",
  "tier": "offline_emergency_card | online_emergency_bundle | full_clinical_history",
  "readerRef": "clinician_or_responder_or_institution_ref",
  "patientPseudonym": "patient_pseudo_...",
  "scope": "scope_value",
  "timestamp": "2026-05-26T12:00:00Z",
  "mode": "online",
  "reasonCode": "treatment | emergency | patient_authorized"
}
```

Delayed offline audit:

```json
{
  "eventType": "record_read",
  "tier": "offline_emergency_card",
  "readerRef": "responder_or_device_ref_if_available",
  "patientPseudonym": "patient_pseudo_or_card_ref",
  "scope": "offline_minimal",
  "readAtDeviceTime": "2026-05-26T12:00:00Z",
  "postedAt": "2026-05-26T13:10:00Z",
  "mode": "offline_delayed",
  "deviceSignature": "signature",
  "delayed": true
}
```

### Integrity

Each tier should support integrity verification:

- Tier 1: signed card payload or signed pointer.
- Tier 2: encrypted bundle hash/CID/commitment anchored to broker metadata.
- Tier 3: manifest and record-level commitments anchored to consent metadata.

### Consent and Review

The patient should be able to review:

- what is in each tier
- which tier is available offline
- which institutions or responder roles are pre-authorized
- which emergency reads occurred
- which normal grants are active, revoked, vetoed, or expired
- which sensitive categories require explicit confirmation

## MVP Recommendation

Implement the tiers in this order:

1. Full Clinical History with patient-driven clinician grant, access broker, and KMS stub.
2. Online Emergency Bundle with break-glass access, presence/fallback paths, veto window, and KMS predicate.
3. Offline Emergency Card with signed payload, finite offline-read budget, and delayed audit queue.

For the first demo, the data can be synthetic and simplified, but the tier boundary should be real in code. Do not implement one giant patient record and merely hide sections in the UI; that would blur the privacy model and make later compliance work harder.
