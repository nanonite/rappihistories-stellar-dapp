# Contract Runner Docker Build Postmortem

## What happened

During E2E-2B work, a one-line access-broker contract change caused the
`contract-runner` Docker image to spend a long time rebuilding Nix and Rust
toolchain state before it reached the actual Rust compile error.

The visible failure was small:

- `access-broker/src/lib.rs` moved Soroban values into stored structs.
- The same values were then borrowed for event emission.
- Rust correctly failed with `borrow of moved value`.

The expensive part was not the bug. The expensive part was where Docker had to
discover the bug.

## Root cause

`components/contracts/Dockerfile` copied the full contracts source tree before
running:

```dockerfile
RUN nix develop .#ci --command cargo build --release --target wasm32-unknown-unknown
```

That made the Nix environment setup, Cargo dependency fetch, Rust toolchain
setup, and contract source compilation one cache unit.

When any Rust source file changed, Docker invalidated the layer and reran the
whole `nix develop ... cargo build` step. A normal compile error therefore
forced the build to rehydrate a large Nix/Rust environment before failing.

## Why it felt worse than a normal Rust build

The contract runner image builds inside Docker, then enters a Nix flake dev
shell, then compiles Soroban contracts for `wasm32-unknown-unknown`.

That path has several heavy pieces:

- Nix flake inputs and store paths.
- Rust overlay/toolchain paths.
- `wasm32-unknown-unknown` standard library support.
- Cargo crates for Soroban SDK and Stellar XDR.
- LLVM/lld and binaryen-related tooling.

Those are reasonable dependencies for a reproducible contract build, but they
must be cached separately from application source edits.

## Fix

The Dockerfile now avoids the Nix build path for the e2e image entirely and
uses a Rust slim builder for contract artifacts.

The Nix flake remains the local development shell, but `contract-runner` no
longer needs to download nixpkgs and rust-overlay just to produce WASM files
inside Docker.

The Dockerfile also has a source-independent `contract-deps` stage. That stage
copies only dependency identity files:

- workspace `Cargo.toml`
- `Cargo.lock`
- each crate `Cargo.toml`

It installs the Rust wasm target, runs Cargo fetches, and uses BuildKit cache
mounts for:

- `/root/.cargo/registry`
- `/root/.cargo/git`
- `/workspace/components/contracts/target`

The contract source is copied only after that dependency/toolchain layer, and
only the crate `src/` directories are copied for source builds.

The intended cache boundary is:

- Dependency or toolchain changes rebuild the expensive Cargo layer.
- Source-only contract changes reuse dependency caches and rerun only the
  contract compile.
- Documentation or scenario file edits under `components/contracts` should not
  invalidate the contract build.

## Operational guidance

For local e2e work:

- Rebuild `contract-runner` only when contracts or deploy scripts change.
- Rebuild `api-indexer` only when indexer code changes.
- Rebuild `kms-gate` only when KMS code changes.
- Expect the first Rust/Cargo dependency build to be slower than warm builds.
- Treat repeated slow contract-runner rebuilds after source-only edits as a
  Docker cache regression.
- The `e2e-runner` service itself is not built. It uses `node:22-bookworm` with
  mounted test code. If `e2e-runner` startup waits for a long build, the usual
  cause is the transitive `tier3-contract-flow -> medichain-contract-runner`
  dependency.

This matters because the e2e loop should spend time validating signed Soroban
transactions and service integration, not repeatedly reconstructing the same
build environment.
