# Integration Workspace and Component CI Boundaries

## Status

Accepted direction for the MVP workspace after Chainlink issue #66: this
repository remains the short-term monorepo, but its long-term role is
`medichain-integration`, the orchestration and end-to-end workspace. Component
repositories should eventually own their source, Dockerfiles or flakes, CI
workflows, and job-container toolchain contracts.

This document is about repository and CI boundaries. It does not change the
product privacy model: clinical content, patient identity, diagnosis, notes,
and linkable personal health information remain encrypted off-chain. Chain data
should stay limited to hashes, commitments, pseudonymous identifiers, consent
metadata, audit events, and supply-chain facts as described in the architecture
and ADR docs.

## Decision

Use option 1: reframe the current repository as the future integration
workspace instead of continuing to expand it as the permanent home for every
component toolchain.

During the MVP monorepo phase, this repository may still contain the web app,
Soroban contracts, service scaffolds, Docker Compose, Verdaccio, and e2e tests.
That is a temporary delivery convenience, not the desired ownership boundary.
The durable boundary is:

- component repos own build/test logic for their component
- component repos own their `.forgejo/workflows/ci.yml`
- component repos own their disposable job image, Dockerfile, flake, or runtime
  contract
- `medichain-integration` owns cross-component wiring, local orchestration,
  integration docs, and e2e flows against pinned component revisions

The Forgejo runner host and runner container should not accumulate every
compiler and runtime needed by the product. The runner surface should stay
small: Docker access, runner registration, label mappings, network access to
approved local services such as Verdaccio, and enough shell tooling to start
job containers. Node, pnpm, Rust, Soroban, wasm targets, backend runtimes, KMS
SDKs, database clients, browser test tooling, and future service-specific
compilers belong in disposable job containers or component-owned images.

## Current Monorepo Phase

Until component boundaries are stable, keep the working layout intact:

- web app source and pnpm workspace entries remain here
- the current `Dockerfile.web`, Verdaccio service, and web CI flow remain the
  working Node/Docker path
- Soroban contract code remains under `contracts/`
- Docker Compose remains the local orchestration surface
- docs and ADRs remain here as the shared source of architecture decisions
- e2e scaffolding belongs here because it exercises the product loop across
  multiple components

Do not move large code trees into new repositories during this phase. Add
clearer ownership markers first, then split only when each component has a
stable build contract and an integration test can consume the component as a
pinned artifact, image, or revision.

## Target Component Repositories

| Repository | Owns | CI/job-container responsibility | Should not require on runner host/container |
| --- | --- | --- | --- |
| `medichain-web-dapp` | Patient, clinician, and pharmacy web surfaces; wallet integration; frontend Stellar clients | Node/pnpm install through Verdaccio; web lint/typecheck/test/build; `Dockerfile.web` or equivalent web image | Rust, Soroban CLI, wasm target, backend service runtimes, KMS SDK toolchains |
| `medichain-contracts` | Soroban contracts and contract tests | Contract-focused Nix flake or contract job image; Rust toolchain; `wasm32-unknown-unknown`; Soroban test/build commands | Node/pnpm web stack, web Docker build chain, service runtime dependencies |
| `medichain-api-indexer` | API, event ingestion, projections, workflow service, database migrations | Backend runtime image; service tests; migration checks; API/indexer image build | Web browser tooling, Soroban compiler stack except generated clients or lightweight test fixtures |
| `medichain-kms-gate` | Key-release predicate service, KMS adapters, security conformance tests | Security-service runtime image; predicate tests; key-release integration tests; image build | Web build stack, contract compiler stack except read-only contract client bindings |
| `medichain-infra` | Optional home for Forgejo runner, Verdaccio, DIND, runner labels, cache policy, registry operations | Runner and registry operational checks; label/image mapping validation; no application build jobs | Product compilers, app dependencies, component test frameworks |
| `medichain-integration` | Compose files, e2e orchestration, architecture docs, pinned component refs/submodules later, release wiring | Pull or build pinned component images; run cross-component smoke/e2e tests; validate local orchestration | Permanent ownership of component-specific compilers or package managers outside integration test images |

## Runner and Toolchain Contract

Forgejo runner infrastructure should provide a clean scheduling and Docker
execution surface, not a shared development machine. The runner should know
which label maps to which job image. The job image should contain the component
toolchain.

For the current repo, `ubuntu-latest` maps to a Node 22 job container because
the active CI workflow is web/pnpm-focused. That mapping is acceptable for the
monorepo phase. It should not become the universal answer for contract,
backend, KMS, or e2e jobs. The live Compose-managed mapping is documented in
[`forgejo-runner-labels.md`](forgejo-runner-labels.md).

As components split:

- web jobs use a Node/pnpm image and Verdaccio registry variables
- contract jobs use a contract-focused Nix or Rust/Soroban image
- service jobs use their service runtime image
- e2e jobs use an integration image that talks to built component services
- infra jobs validate runner, DIND, Verdaccio, labels, and networks

Do not install these on the Forgejo runner host or long-lived runner container:

- project Node dependencies or global pnpm state for component builds
- Rust toolchains, Soroban CLI, or wasm targets
- backend service SDKs or database client stacks for app tests
- browser automation stacks for component-owned UI tests
- KMS provider CLIs or secrets tooling for component test execution
- repo-specific build caches that make jobs depend on hidden runner state

## Nix Flake Scope

The Nix flake tracked in Chainlink #64 should be contract-focused. It should
make Soroban/Rust/WASM contract work reproducible without becoming a universal
workspace development shell.

Web and dApp development remain Docker plus Verdaccio contained. Backend,
KMS, and integration jobs should get their own container or flake only when
their boundaries justify it. A single "everything shell" would recreate the
polluted runner/workspace problem this decision is meant to avoid.

## Migration Checklist

1. Current monorepo phase
   - Keep the working web, Verdaccio, Docker Compose, and contract layout in
     this repo.
   - Add documentation and ownership markers before moving code.
   - Keep e2e and integration design here.

2. Introduce the contract-focused flake
   - Scope the flake to `medichain-contracts` needs: Rust, Soroban, WASM, and
     contract tests.
   - Do not include the web/dApp toolchain or future service runtimes.
   - Use it locally and in contract CI before relying on it from integration.

3. Isolate web Docker CI
   - Keep Node/pnpm installs behind Verdaccio.
   - Make the web CI job image and workflow explicitly web-owned.
   - Avoid adding Rust/Soroban or service dependencies to the web job image.

4. Isolate service Dockerfiles
   - Give `api-indexer` and `kms-gate` separate Dockerfiles and CI jobs when
     their service scaffolds become real.
   - Keep service dependency approval, build, test, and runtime contracts
     component-owned.

5. Introduce pinned refs only after stable boundaries
   - Use submodules, pinned Git refs, released images, or artifacts only after
     each component has a reproducible CI contract.
   - Avoid early submodule churn while files are still moving frequently inside
     the monorepo.

6. Move e2e orchestration into the integration role
   - Keep Compose, seed data, smoke tests, and full product-loop e2e tests in
     `medichain-integration`.
   - Run e2e against pinned component images or revisions, not implicit local
     toolchains on the runner.

## Practical Guardrails

- Prefer docs and CI comments over behavior changes until the split path is
  ready.
- Do not use integration CI to compile every component from source by default.
  It should orchestrate known component artifacts, with source builds reserved
  for explicit local development or release tasks.
- Keep Verdaccio as the approved npm cache for Node jobs while this repo owns
  the web CI path.
- Keep Docker Compose useful for local MVP development even after components
  split; it becomes the integration repo's main operator surface.
