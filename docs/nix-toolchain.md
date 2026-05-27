# Nix Contract Toolchain

The Soroban contract component owns `components/contracts/flake.nix` for
contract development and contract CI. It is not a universal workspace shell.
Web and dApp work stays on the existing Docker, pnpm, and Verdaccio path described in
[`docs/dependency-management.md`](dependency-management.md).

## Local Contract Shell

Enter the contract shell from the contract component:

```bash
cd components/contracts
nix develop
```

The shell provides the contract-focused toolchain:

- Rust/Cargo with `wasm32-unknown-unknown` installed
- `rustfmt`, `clippy`, and `rust-src`
- Binaryen for WASM inspection and optimization utilities
- Native build/link tools needed by Rust crates
- Git and CA certificates for normal Nix/Rust operations

The shell intentionally does not include Node.js, pnpm, Docker, Docker Compose,
or service-specific SDKs. Keep those toolchains in their component-owned Docker
or CI paths so the integration workspace does not become an all-purpose build
environment.

Useful checks:

```bash
cd components/contracts
nix flake check
nix develop --command cargo --version
nix develop --command cargo test
nix develop --command cargo build --release --target wasm32-unknown-unknown
```

The workspace WASM build writes artifacts under:

```text
components/contracts/target/wasm32-unknown-unknown/release/
```

## CI Shell

The flake also exposes `.#ci` for Forgejo contract jobs:

```bash
cd components/contracts
nix develop .#ci
```

`.#ci` uses the same contract shell as local development. It does not set npm
registry variables because contract CI should not install Node dependencies.
If a future contract job needs generated TypeScript clients, keep that as an
explicit cross-component step instead of folding the web toolchain into this
flake.

The current contract CI flow validates:

```bash
nix flake check ./components/contracts --no-write-lock-file --print-build-logs
nix develop ./components/contracts#ci --command cargo --version
nix develop ./components/contracts#ci --command bash -lc 'cd components/contracts && cargo test'
nix develop ./components/contracts#ci --command bash -lc 'cd components/contracts && cargo build --release --target wasm32-unknown-unknown'
```

## Forgejo Runner Integration

`e2e/docker-compose.yml` registers a `nix` runner label:

```text
nix:docker://docker.io/nixos/nix:latest
```

Set `FORGEJO_NIX_RUNNER_IMAGE` before starting the runner if the operator wants
to pin the base Nix job image to a specific digest or tag. The flake lock pins
the actual Rust and native package set used inside the job.

After changing the runner image or recreating Docker-in-Docker, keep the DIND
network attachment from `docs/dependency-management.md` intact. The web job
still needs Verdaccio access, even though the contract job itself does not use
npm.

## Soroban CLI Status

The flake packages the Rust/WASM toolchain needed for native tests and release
WASM builds. It does not currently package the Stellar/Soroban CLI. Add that
later only through a maintained Nix package, overlay, or documented binary
source; do not add a custom download path just to satisfy deployment commands.
