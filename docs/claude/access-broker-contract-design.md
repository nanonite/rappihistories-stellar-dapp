# Access Broker — Soroban Contract Design

Companion to *Integrated Health Records + Drug Supply Chain on Stellar* (§4–§5, §16). This is the contract where the subtle bugs live, so the design is written **hole-first**: every step names the way it can go wrong.

> **Status:** illustrative, unaudited skeleton. Not yet compiled. APIs follow `soroban-sdk` conventions but must be verified against the pinned SDK version before use.

---

## 1. Trust model & separation of concerns

The broker is a **policy + audit layer**, not a key vault. Three parties, three jobs:

| Layer | Holds | Job |
| :-- | :-- | :-- |
| **Broker contract** (on-chain) | commitments, grants, audit events | authorize · record · expire |
| **KMS / re-encryption** (off-chain) | the ability to re-wrap data keys | release a key **only against committed on-chain grant state** |
| **Encrypted store** (off-chain) | the ciphertext | serve the blob by locator |

A read succeeds only when *all three* agree: the broker has a valid, unexpired, unrevoked grant **committed** to the ledger; the KMS re-wraps the data key to the requester after re-checking that committed grant; the requester fetches the blob and verifies it against the on-chain commitment. No single layer can leak data alone.

**Design rule that follows from this:** the contract returns only non-secret data. Secrets never transit the chain, never appear in a return value, never appear in simulation.

---

## 2. Data model

```rust
use soroban_sdk::{
    contract, contractimpl, contracttype, contracterror,
    Address, Bytes, BytesN, Env, Symbol, symbol_short, panic_with_error,
};

#[contract]
pub struct AccessBroker;

#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    Admin,                    // instance  — single admin key (MVP); multisig [future]
    IssuerRoot,               // instance  — trusted credential-issuer pubkey
    Record(BytesN<32>),       // persistent — RecordMeta
    Grant(BytesN<32>),        // persistent (normal) | temporary (break-glass) — Grant
    PatientToken(Address),    // persistent — patient's opt-in card/bracelet pubkey
    SpentNonce(BytesN<32>),   // temporary  — presence-proof replay guard
}

#[contracttype] #[derive(Clone, PartialEq)]
pub enum Tier { OfflineCard, EmergencyBundle, FullHistory }

#[contracttype] #[derive(Clone, PartialEq)]
pub enum GrantType { Normal, BreakGlass, TokenlessFallback }

#[contracttype] #[derive(Clone)]
pub struct RecordMeta {
    pub owner: Address,         // patient pseudonym
    pub tier: Tier,
    pub category: Symbol,       // "cardiology", "behavioral_health", ...
    pub sensitive: bool,        // true => needs an explicit per-category grant
    pub commitment: BytesN<32>, // hash of the encrypted off-chain blob
    pub locator: Bytes,         // opaque storage pointer — NOT a secret
}

#[contracttype] #[derive(Clone)]
pub struct Grant {
    pub record: BytesN<32>,
    pub grantee: Address,
    pub gtype: GrantType,
    pub purpose: Symbol,
    pub scope_category: Symbol, // must match RecordMeta.category (allowlist)
    pub expires_at: u64,        // BUSINESS expiry (unix secs) — never the storage TTL
    pub revoked: bool,
}

#[contracttype] #[derive(Clone)]
pub struct PresenceProof {
    pub token_pubkey: BytesN<32>, // the card that was tapped
    pub nonce: BytesN<32>,        // fresh, single-use
    pub expires_at: u64,          // short window (e.g. now + 5 min)
    pub signature: BytesN<64>,    // sign(domain || grantee || record || nonce || expires_at)
}

#[contracttype] #[derive(Clone)]
pub struct CredentialProof {
    pub role: Symbol,             // "clinician" | "responder" | "pharmacy"
    pub subject: Address,         // MUST equal the authorized caller
    pub expires_at: u64,
    pub issuer_sig: BytesN<64>,   // issuer signs (role || subject || expires_at)
}

/// What the contract returns. Deliberately contains NO secret material.
#[contracttype] #[derive(Clone)]
pub struct Capability {
    pub grant_id: BytesN<32>,
    pub locator: Bytes,
    pub commitment: BytesN<32>,
}

#[contracterror] #[derive(Copy, Clone)]
pub enum Error {
    NoSuchRecord = 1, BadCredential = 2, CredentialNotForCaller = 3,
    NoGrant = 4, GrantExpired = 5, GrantRevoked = 6, ScopeMismatch = 7,
    SensitiveNeedsExplicitGrant = 8, OfflineTierNotBrokered = 9,
    StalePresence = 10, WrongToken = 11, NoTokenRegistered = 12,
    NonceReplayed = 13, BadPresenceSig = 14, FallbackNeedsDualSign = 15,
}
```

**Storage-class decisions (and the trap):** `Grant` for a break-glass read lives in **temporary** storage so it *also* self-cleans, but its security lifetime is `expires_at`, checked in code — **not** the storage TTL. Conflating the two is Hole B (§5).

---

## 3. The `request_access` flow

```rust
const MAX_PRESENCE_WINDOW: u64 = 300;   // secs
const BREAK_GLASS_WINDOW:  u64 = 6 * 3600;

#[contractimpl]
impl AccessBroker {
    pub fn request_access(
        env: Env,
        requester: Address,
        record_id: BytesN<32>,
        purpose: Symbol,
        cred: CredentialProof,
        presence: Option<PresenceProof>,
    ) -> Capability {
        // (0) The caller must authorize THIS call.
        requester.require_auth();

        // (1) Credential must be valid AND bound to the authorized caller.
        verify_credential(&env, &requester, &cred);   // Hole E guarded here

        let meta: RecordMeta = env.storage().persistent()
            .get(&DataKey::Record(record_id.clone()))
            .unwrap_or_else(|| panic_with_error!(&env, Error::NoSuchRecord));

        let now = env.ledger().timestamp();

        // (2) Choose and check the authorization path.
        let (gtype, expires_at) = match meta.tier {
            Tier::FullHistory =>
                authorize_normal(&env, &requester, &record_id, &meta, now),     // Holes F, C
            Tier::EmergencyBundle =>
                authorize_emergency(&env, &requester, &record_id, &meta, &cred, &presence, now), // Holes A-D, J
            Tier::OfflineCard =>
                panic_with_error!(&env, Error::OfflineTierNotBrokered),         // self-verifying off-chain
        };

        // (3) AUDIT FIRST — emit before anything is handed back (Hole I).
        env.events().publish(
            (symbol_short!("access"), meta.owner.clone(), requester.clone()),
            (record_id.clone(), tier_code(&meta.tier), purpose.clone(), gtype_code(&gtype), now),
        );

        // (4) Commit the grant so the off-chain KMS can verify COMMITTED state (Hole A).
        let grant_id = derive_grant_id(&env, &requester, &record_id, now);
        let grant = Grant {
            record: record_id.clone(), grantee: requester.clone(), gtype,
            purpose, scope_category: meta.category.clone(), expires_at, revoked: false,
        };
        store_grant(&env, &grant_id, &grant, expires_at);

        // (5) Return a NON-SECRET capability. The key is released off-chain,
        //     only after the KMS sees this grant committed (defeats simulation scrape).
        Capability { grant_id, locator: meta.locator, commitment: meta.commitment }
    }

    pub fn revoke(env: Env, owner: Address, grant_id: BytesN<32>) {
        owner.require_auth();
        let mut g: Grant = load_grant(&env, &grant_id);
        // ownership check: the record's owner must equal `owner`
        let meta: RecordMeta = env.storage().persistent()
            .get(&DataKey::Record(g.record.clone()))
            .unwrap_or_else(|| panic_with_error!(&env, Error::NoSuchRecord));
        if meta.owner != owner { panic_with_error!(&env, Error::NoGrant); }
        g.revoked = true;
        store_grant(&env, &grant_id, &g, g.expires_at);
        env.events().publish((symbol_short!("revoke"), owner), grant_id);
        // KMS re-checks committed state at release time, so this cuts future reads (Hole C).
    }
}
```

### 3.1 Normal (Tier-3) authorization

```rust
fn authorize_normal(
    env: &Env, requester: &Address, record_id: &BytesN<32>,
    meta: &RecordMeta, now: u64,
) -> (GrantType, u64) {
    let grant_id = expected_normal_grant_id(env, requester, record_id);
    let g: Grant = env.storage().persistent()
        .get(&DataKey::Grant(grant_id))
        .unwrap_or_else(|| panic_with_error!(env, Error::NoGrant));

    if g.revoked { panic_with_error!(env, Error::GrantRevoked); }
    if now >= g.expires_at { panic_with_error!(env, Error::GrantExpired); }   // business clock, not TTL
    if g.grantee != *requester { panic_with_error!(env, Error::NoGrant); }

    // Allowlist scope check; sensitive categories need an explicit, matching grant (Hole F).
    if g.scope_category != meta.category { panic_with_error!(env, Error::ScopeMismatch); }
    if meta.sensitive && g.scope_category != meta.category {
        panic_with_error!(env, Error::SensitiveNeedsExplicitGrant);
    }
    (GrantType::Normal, g.expires_at)
}
```

### 3.2 Emergency authorization — presence path and tokenless fallback

```rust
fn authorize_emergency(
    env: &Env, requester: &Address, record_id: &BytesN<32>,
    meta: &RecordMeta, cred: &CredentialProof,
    presence: &Option<PresenceProof>, now: u64,
) -> (GrantType, u64) {
    // role gate
    require_role(env, cred, /* one of */ &[symbol_short!("responder"), symbol_short!("clinician")]);

    match presence {
        Some(p) => {
            verify_presence(env, requester, record_id, meta, p, now);   // Holes A(replay)/B/D
            (GrantType::BreakGlass, now + BREAK_GLASS_WINDOW)
        }
        None => {
            // Tokenless fallback (patient opted out / lost card):
            //  - only the vital subset (enforced by RecordMeta.sensitive == false upstream),
            //  - requires institution + second clinician co-sign (Hole J),
            //  - heavier audit topic for monitoring.
            require_dual_cosign(env, cred);          // panics FallbackNeedsDualSign if absent
            env.events().publish(
                (symbol_short!("fallback"), meta.owner.clone(), requester.clone()), now);
            (GrantType::TokenlessFallback, now + BREAK_GLASS_WINDOW)
        }
    }
}

fn verify_presence(
    env: &Env, requester: &Address, record_id: &BytesN<32>,
    meta: &RecordMeta, p: &PresenceProof, now: u64,
) {
    // (a) freshness — bounded window in BOTH directions
    if now >= p.expires_at || p.expires_at > now + MAX_PRESENCE_WINDOW {
        panic_with_error!(env, Error::StalePresence);
    }
    // (b) the tapped card MUST be the patient's registered token (binds proof to THIS patient, Hole D)
    let registered: BytesN<32> = env.storage().persistent()
        .get(&DataKey::PatientToken(meta.owner.clone()))
        .unwrap_or_else(|| panic_with_error!(env, Error::NoTokenRegistered));
    if registered != p.token_pubkey { panic_with_error!(env, Error::WrongToken); }

    // (c) replay guard — single-use nonce in temporary storage
    if env.storage().temporary().has(&DataKey::SpentNonce(p.nonce.clone())) {
        panic_with_error!(env, Error::NonceReplayed);
    }

    // (d) signature over a FULLY-BOUND, domain-separated message
    //     msg = "hcstellar:presence:v1" || requester || record_id || nonce || expires_at
    let msg = build_presence_msg(env, requester, record_id, &p.nonce, p.expires_at);
    env.crypto().ed25519_verify(&p.token_pubkey, &msg, &p.signature);  // panics on bad sig

    // (e) burn the nonce; TTL only needs to outlast the freshness window
    env.storage().temporary().set(&DataKey::SpentNonce(p.nonce.clone()), &true);
    env.storage().temporary().extend_ttl(&DataKey::SpentNonce(p.nonce.clone()),
        MAX_PRESENCE_WINDOW as u32, MAX_PRESENCE_WINDOW as u32);
}
```

---

## 4. Why the return value carries no secret (the simulation defense, restated in code terms)

A `Capability` is `{ grant_id, locator, commitment }`. Each field is already public-equivalent: the locator points at *ciphertext*, the commitment is a hash, the grant_id is an identifier. Knowing all three lets you **fetch ciphertext you still cannot read**. To actually decrypt you must obtain the re-wrapped data key from the KMS, and the KMS will only re-wrap when it observes the grant **committed** in ledger state and unrevoked and unexpired.

A simulated (preflighted, unsubmitted) `request_access` commits nothing — no grant, no event — so the KMS sees no authorization and releases no key. The attacker who scrapes the simulation result walks away with a hash and a pointer to ciphertext. That is the entire point.

---

## 5. The bug catalog (read this before the code)

| # | Hole | Where | Mitigation in this design |
| :-- | :-- | :-- | :-- |
| **A** | **Simulation scrape** — preflight returns secrets without committing audit | return value of `request_access` | Return non-secret `Capability` only; KMS releases key against **committed** grant state, never simulation |
| **B** | **TTL ≠ expiry** — leaning on temporary-storage auto-delete as the security clock; `extend_ttl` is callable by anyone | `Grant` lifetime | Always enforce `now >= expires_at` in code; TTL is hygiene only |
| **C** | **Bearer capability** — KMS honoring a presented capability token, so revocation is bypassed | KMS ↔ broker contract | Capabilities are non-bearer; KMS re-derives authz from current committed grant every release |
| **D** | **Unbound presence proof** — tap for patient A / record X replayed for B / Y, or relayed between responders | `verify_presence` | Sign over `domain ‖ requester ‖ record_id ‖ nonce ‖ expires_at`; check token == record owner's registered token; single-use nonce |
| **E** | **Credential not bound to caller** — a stolen credential blob authorizes anyone | `verify_credential` | Issuer signs over `subject`; require `cred.subject == requester` after `require_auth` |
| **F** | **Sensitive-category leak via "full" grant** | `authorize_normal` | Allowlist scope match; `sensitive` records need a grant explicitly scoped to that category (default-deny) |
| **G** | **Issuer-revocation staleness** — cached trust root can't see a just-revoked credential | `verify_credential` | Consult current issuer/revocation state (cross-contract); if cached, cap and document the staleness window |
| **H** | **Metering DoS** — scanning `Vec`/`Map` of grants blows the resource budget and bricks the call | all lookups | O(1) keyed `DataKey` lookups; never iterate unbounded collections on the hot path |
| **I** | **Unaudited branch** — an authorization path returns before the audit emit | `request_access` step (3) | Single emit point reached by all paths *before* the capability is built; emit precedes grant write |
| **J** | **Tokenless fallback** — the accepted residual door; insider collusion on the dual co-sign | `authorize_emergency` (None) | Vital-subset only, institution + second-clinician co-sign, distinct `fallback` audit topic for anomaly monitoring |

Two of these are *philosophy-driven*, not just technical: **J** exists because the patient may rightfully refuse a token, and **A/C** exist because the audit trail is the only thing standing between "legitimate emergency access" and "silent theft" — so any path that yields data without a committed audit event is, by definition, a critical bug.

---

## 6. What to hand an auditor

- **Adversarial preflight test:** simulate `request_access` for a record you have no grant for; confirm the result is useless without a submitted tx, and that the KMS stub refuses release on simulation-only state.
- **Expiry/TTL divergence test:** extend a break-glass grant's storage TTL externally; confirm access still fails once `expires_at` passes.
- **Revocation race test:** issue capability, revoke, then attempt release; confirm KMS refuses.
- **Presence-binding fuzz:** mutate each field of the signed message (swap record, swap requester, reuse nonce, stretch expiry) and confirm each mutation is rejected.
- **Credential-binding test:** present a valid credential whose `subject` ≠ caller; confirm `CredentialNotForCaller`.
- **Sensitive-scope test:** attempt to read a `sensitive` record under a generic full-history grant; confirm `SensitiveNeedsExplicitGrant`.
- **Metering test:** worst-case inputs stay within the resource budget.

---

## 7. Open questions for the next pass

- **KMS decentralization.** A single KMS is a re-centralization of the secret layer. Threshold re-encryption / MPC across independent key-holders is the `[future]` answer; for MVP, document the single-KMS trust assumption alongside the single-admin-key one.
- **Presence nonce source.** Contract-issued challenge vs. recent-ledger-derived nonce — pick one and pin the freshness semantics; the skeleton assumes a server/contract-issued single-use nonce.
- **Cross-contract cost of live credential checks (Hole G)** vs. cached roots — measure before deciding.
- **Tokenless fallback scope** — exactly which fields constitute the "vital subset," and whether that set is patient-tunable.
