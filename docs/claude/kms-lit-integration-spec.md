# KMS-via-Lit Integration — Formal Interface Spec

Companion to the broker design. Specifies the interaction between the **dApp/client**, the **broker contract (Stellar/Soroban)**, and the **decentralized KMS (Lit Protocol)** that releases decryption keys. The contract is specified formally so the MVP can ship a **stub** that provably refines the same behavior as the future Lit implementation.

> **MVP stance:** architect to this interface now, stub the KMS, defer Lit. The formal contract — not the implementation — is the source of truth; stub and Lit gate must both satisfy it.

---

## 1. Actors and the one safety property that matters

| Actor | Role |
| :-- | :-- |
| **Client** | requester app (clinician/responder) and patient app |
| **Broker** | Soroban contract — authorizes, audits, holds `Grant` state (commitment, scope, `revealAt`, `expiresAt`, `revoked`, `vetoed`) |
| **KMS (Lit)** | decentralized threshold network — releases the wrapped data key *iff* the broker grant satisfies the release predicate |
| **Store** | off-chain ciphertext (IPFS/S3/…); returns encrypted blobs only |

**The property the whole integration exists to guarantee:**

> A usable decryption key is released to a requester **only if**, at the moment of release, there exists a Stellar-**committed** grant `g` with `g.requester = caller ∧ ¬g.revoked ∧ ¬g.vetoed ∧ revealAt ≤ now < expiresAt`.

Everything below is in service of making that statement true and checkable. It folds in three earlier hardening decisions: the **simulation-scrape** defense (release needs *committed* state, not a simulated/returned value), **revocation/veto** honoring (predicate re-evaluated against *current* state — non-bearer), and the **30-second veto window** (`revealAt = submitTime + Window`).

---

## 2. Formal model (TLA+)

A model-checkable sketch for TLC with small constants. The `ReleaseKey` guard *is* the predicate above; the invariants assert the implementation can never violate it.

```tla
---------------------------- MODULE KeyReleaseProtocol ----------------------------
EXTENDS Naturals, FiniteSets

CONSTANTS Gid, Requester, Owner, Window, Lifetime, MaxTime

VARIABLES
    clock,      \* Nat: current time
    grant,      \* [Gid -> grant record]
    released    \* set of release events [gid, r, t]

NullRec ==
    [ exists |-> FALSE, committed |-> FALSE,
      req |-> CHOOSE r \in Requester : TRUE, own |-> CHOOSE o \in Owner : TRUE,
      revealAt |-> 0, expiresAt |-> 0, revoked |-> FALSE, vetoed |-> FALSE ]

TypeOK ==
    /\ clock \in 0..MaxTime
    /\ grant \in [Gid -> [exists: BOOLEAN, committed: BOOLEAN, req: Requester, own: Owner,
                          revealAt: Nat, expiresAt: Nat, revoked: BOOLEAN, vetoed: BOOLEAN]]
    /\ released \subseteq [gid: Gid, r: Requester, t: Nat]

Init == clock = 0 /\ grant = [g \in Gid |-> NullRec] /\ released = {}

\* A SUBMITTED (committed) authorization lands on-chain. There is deliberately NO action
\* that sets committed = TRUE without submitting: a simulated/preflighted request commits
\* nothing, so it can never enable a release. (This is the simulation-scrape defense.)
Submit(g, r, o) ==
    /\ ~grant[g].exists
    /\ grant' = [grant EXCEPT ![g] =
          [exists |-> TRUE, committed |-> TRUE, req |-> r, own |-> o,
           revealAt |-> clock + Window, expiresAt |-> clock + Window + Lifetime,
           revoked |-> FALSE, vetoed |-> FALSE]]
    /\ UNCHANGED <<clock, released>>

\* Conscious patient cancels within the veto window.
Veto(g) ==
    /\ grant[g].exists /\ ~grant[g].vetoed /\ clock < grant[g].revealAt
    /\ grant' = [grant EXCEPT ![g].vetoed = TRUE]
    /\ UNCHANGED <<clock, released>>

\* Revocation cuts FUTURE releases only (cannot un-leak an already-released key).
Revoke(g) ==
    /\ grant[g].exists /\ ~grant[g].revoked
    /\ grant' = [grant EXCEPT ![g].revoked = TRUE]
    /\ UNCHANGED <<clock, released>>

\* The KMS (Lit Action) releases iff the on-chain predicate holds NOW.
ReleaseKey(g, r) ==
    /\ grant[g].exists
    /\ grant[g].committed
    /\ grant[g].req = r
    /\ ~grant[g].revoked
    /\ ~grant[g].vetoed
    /\ clock >= grant[g].revealAt
    /\ clock <  grant[g].expiresAt
    /\ released' = released \cup { [gid |-> g, r |-> r, t |-> clock] }
    /\ UNCHANGED <<clock, grant>>

Tick == clock < MaxTime /\ clock' = clock + 1 /\ UNCHANGED <<grant, released>>

Next ==
    \/ \E g \in Gid, r \in Requester, o \in Owner : Submit(g, r, o)
    \/ \E g \in Gid : Veto(g)
    \/ \E g \in Gid : Revoke(g)
    \/ \E g \in Gid, r \in Requester : ReleaseKey(g, r)
    \/ Tick

Spec == Init /\ [][Next]_<<clock, grant, released>>

\* -------- Safety invariants (check with TLC) --------

\* (1) No key without a committed grant to the right requester.
\*     Defeats the simulation-scrape AND credential/requester impersonation.
CommitSafety ==
    \A x \in released :
        grant[x.gid].exists /\ grant[x.gid].committed /\ grant[x.gid].req = x.r

\* (2) A vetoed grant is NEVER released. This is your 30-second window, as a theorem:
\*     veto can only fire while clock < revealAt; release requires clock >= revealAt and
\*     ~vetoed; vetoed is monotonic -> a vetoed grant can never satisfy the release guard.
VetoSafety == \A x \in released : ~grant[x.gid].vetoed

\* (3) Every release happened strictly inside the authorized window.
WindowSafety ==
    \A x \in released :
        x.t >= grant[x.gid].revealAt /\ x.t < grant[x.gid].expiresAt

Safety == CommitSafety /\ VetoSafety /\ WindowSafety
=============================================================================
```

**Liveness (stated, not modeled above):** a committed, un-vetoed, un-revoked grant whose window has opened is eventually releasable — i.e. the legitimate (e.g. unconscious-patient) read is delayed by **at most `Window`**, never *denied*. Add `WF_vars(ReleaseKey)` and check `<>(releasable(g) ~> released)` in a refined model. This is the formal counterpart to "a 30-second wait beats no records."

**Criticality-graduated window:** model `Window` as a function of data class — `Window(critical) = 0` (instant: allergies, anticoagulants, implants), `Window(extended) = 30s`. `WindowSafety` and `VetoSafety` still hold per-class; only the most time-critical, least-stigmatizing subset skips the veto.

---

## 3. Design-by-contract interface

What the client codes against. Both the stub and the Lit gate implement `KmsGate` and must refine §2.

```ts
type Bytes32 = string; type StellarPubKey = string; type WrappedKey = Uint8Array;

interface ReleaseRequest {
  grantId: Bytes32;
  requester: StellarPubKey;
  requesterAuth: Ed25519Sig;   // proves control of `requester` over a fresh challenge
  locator: Bytes;              // informational; ciphertext lives here
}

interface KmsGate {
  // POST: returns a WrappedKey IFF, at evaluation time, the broker grant satisfies the
  //       §1 predicate (committed ∧ req=requester ∧ ¬revoked ∧ ¬vetoed ∧ revealAt≤now<expiresAt).
  //       Returns Denied otherwise. MUST re-read COMMITTED Stellar state on every call
  //       (non-bearer: a prior success grants no future entitlement).
  requestKey(req: ReleaseRequest): Promise<WrappedKey | Denied>;
}
```

Obligations that make the §2 invariants hold in practice:

- **CommitSafety →** the gate MUST read *committed ledger state* (a live `getLedgerEntries` on the broker), never a client-supplied or simulated value. A simulated `request_access` writes nothing, so the entry is absent ⇒ deny.
- **Non-bearer →** the gate re-evaluates the predicate every call. A `ReleaseRequest` is not a ticket; revocation/veto between calls is honored.
- **Requester binding →** `requesterAuth` must verify (Ed25519) over a fresh challenge bound to `grantId`, so a captured request can't be replayed by another party.

---

## 4. The Lit Action — Stellar-state bridge (the seam to harden)

Lit's native access-control conditions read EVM/Cosmos/Solana state, **not Stellar**. The bridge is therefore a **Lit Action** (in-network JS) that reads committed Stellar state and gates the threshold decryption. This RPC read is the new trust seam.

```js
// litAction_stellarGrantGate.js — runs on each Lit node; nodes threshold-decrypt only on "granted"
const go = async () => {
  // jsParams: grantId, requester, requesterAuthOk (verified by Lit auth), brokerId, rpcUrl
  const entry = await fetchCommittedGrant(rpcUrl, brokerId, grantId);   // getLedgerEntries (live, not simulated)
  const now   = await fetchLedgerTime(rpcUrl);

  const granted =
        entry && entry.exists && entry.committed &&
        entry.requester === requester &&
        !entry.revoked && !entry.vetoed &&
        now >= entry.revealAt && now < entry.expiresAt;       // == the TLA+ ReleaseKey guard

  Lit.Actions.setResponse({ response: granted ? "granted" : "denied" });
  // only on "granted" does each node contribute its decryption share
};
```

**Hardening the seam (do not skip):**
- **Independent reads, then agree.** Each Lit node queries an *independent* Stellar RPC; require N-of-M node agreement so one lying/compromised RPC can't forge a release. A single shared RPC re-centralizes everything you just decentralized.
- **Committed-only.** Use `getLedgerEntries` against live state — never a simulated/preflighted result. This is the on-chain half of CommitSafety.
- **TTL interaction (cross-ref storage strategy).** If the grant entry's Soroban storage TTL has lapsed and the entry is archived, the live read returns nothing ⇒ deny. So critical grant entries MUST be kept alive (Merkle-rooted, sponsored auto-renewal). A denied-because-archived emergency read is a *correctness* bug, not just hygiene.
- **Predicate parity.** The Lit Action predicate, the broker's own checks, and the TLA+ `ReleaseKey` guard must be the *same* boolean. Drift between them is where a future bug hides; keep them generated from one shared definition if possible.

---

## 5. Broker delta for the veto window

`request_access` (from the broker design) gains a `Window` per data class and writes `reveal_at`; add a `veto`:

```rust
// in request_access, when building the grant:
let window = window_for(&meta);              // 0 for critical subset, e.g. 30 for extended
let reveal_at = now + window;
// store Grant { ..., reveal_at, vetoed: false, .. }

pub fn veto(env: Env, owner: Address, grant_id: BytesN<32>) {
    owner.require_auth();
    let mut g: Grant = load_grant(&env, &grant_id);
    let meta: RecordMeta = get_record(&env, &g.record);
    if meta.owner != owner { panic_with_error!(&env, Error::NoGrant); }
    if env.ledger().timestamp() >= g.reveal_at { panic_with_error!(&env, Error::WindowClosed); }
    g.vetoed = true;
    store_grant(&env, &grant_id, &g, g.expires_at);
    env.events().publish((symbol_short!("veto"), owner), grant_id);
}
```

Note the guard `now >= g.reveal_at => WindowClosed` mirrors the TLA+ `Veto` precondition `clock < revealAt`, which is what makes `VetoSafety` hold end-to-end.

---

## 6. MVP stub boundary

Ship `LocalStubGate`; define `LitGate`; swap by config.

```ts
// MVP: enforces the SAME predicate by reading committed Stellar testnet state directly
// from a server you run. No threshold network yet — single trust point, documented.
class LocalStubGate implements KmsGate { /* read getLedgerEntries; apply §1 predicate; re-wrap */ }

// FUTURE: the Lit Action of §4 across the Lit network. Same interface, same predicate.
class LitGate implements KmsGate { /* dispatch litAction_stellarGrantGate; collect shares */ }
```

What the stub deliberately fakes vs. keeps real:

| Concern | MVP stub | Why it's safe to stub |
| :-- | :-- | :-- |
| Threshold/decentralization | single server holds re-wrap ability | documented single-trust-point, like the single admin key; behavior (the predicate) is identical |
| Stellar state read | direct RPC from your server | same `getLedgerEntries` the Lit Action will use |
| Release predicate | **real, not stubbed** | this is the contract; it must match §2 exactly from day one |
| Veto window / revocation | **real, not stubbed** | safety properties depend on them |

The rule: **stub the decentralization, never stub the predicate.** Anything that affects `Safety` (§2) is real in the MVP; only *who holds the keying material* is deferred.

---

## 7. What to verify

- Run TLC on §2 with small `Gid/Requester/Owner` and `Window, Lifetime, MaxTime`; confirm `CommitSafety ∧ VetoSafety ∧ WindowSafety` hold and find no counterexample.
- Conformance test: `LocalStubGate` and (later) `LitGate` must produce identical `granted/denied` decisions on a shared table of grant states — this is the refinement check that the stub and Lit agree with the model.
- Seam test: feed the Lit Action a *simulated* (uncommitted) grant and a *lying* RPC; confirm deny in both.
- Window test: veto at `revealAt - 1` ⇒ never released; veto attempt at `revealAt` ⇒ `WindowClosed`, release proceeds.
