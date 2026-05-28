#!/usr/bin/env bash
set -euo pipefail

CONTRACTS_DIR="${CONTRACTS_DIR:-/workspace/components/contracts}"
CONTRACT_IDS_FILE="${CONTRACT_IDS_FILE:-/shared/contract-ids.json}"
SEED_IDENTITIES_FILE="${SEED_IDENTITIES_FILE:-/shared/seed-identities.json}"
STELLAR_RPC_URL="${STELLAR_RPC_URL:-http://stellar-local:8000}"
STELLAR_NETWORK="${STELLAR_NETWORK:-local}"
STELLAR_NETWORK_PASSPHRASE="${STELLAR_NETWORK_PASSPHRASE:-Standalone Network ; February 2017}"
SOURCE_ACCOUNT="${SOURCE_ACCOUNT:-medichain-admin}"

contracts=(
  "identity:identity"
  "accessBroker:access_broker"
  "prescription:prescription"
  "supplychain:supplychain"
  "incentive:incentive"
)

seed_aliases=(
  "admin:admin"
  "patient-1:patient"
  "patient-2:patient"
  "clinician-1:clinician"
  "clinician-2:clinician"
  "pharmacy:pharmacy"
  "responder:responder"
)

main() {
  mkdir -p "$(dirname "$CONTRACT_IDS_FILE")" "$(dirname "$SEED_IDENTITIES_FILE")"
  configure_local_network
  build_contracts
  write_seed_identities
  deploy_contracts
}

configure_local_network() {
  if has_stellar_cli; then
    stellar network add "$STELLAR_NETWORK" \
      --global \
      --rpc-url "$STELLAR_RPC_URL" \
      --network-passphrase "$STELLAR_NETWORK_PASSPHRASE" >/dev/null 2>&1 || true
  fi
}

build_contracts() {
  if [[ ! -d "$CONTRACTS_DIR" ]]; then
    echo "Contract directory not found: $CONTRACTS_DIR" >&2
    exit 1
  fi

  (cd "$CONTRACTS_DIR" && cargo build --release --target wasm32-unknown-unknown)
}

write_seed_identities() {
  local json_entries=()
  local alias role public_key

  for alias_role in "${seed_aliases[@]}"; do
    alias="${alias_role%%:*}"
    role="${alias_role##*:}"
    public_key="$(ensure_funded_identity "medichain-${alias}")"
    json_entries+=("$(printf '{"alias":"%s","role":"%s","publicKey":"%s","funded":true}' "$alias" "$role" "$public_key")")
  done

  write_json_array_file "$SEED_IDENTITIES_FILE" "identities" "${json_entries[@]}"
  echo "Wrote seed identities to $SEED_IDENTITIES_FILE"
}

ensure_funded_identity() {
  local name="$1"
  local public_key

  if has_stellar_cli; then
    stellar keys generate "$name" --global --network "$STELLAR_NETWORK" >/dev/null 2>&1 || true
    stellar keys fund "$name" --network "$STELLAR_NETWORK" >/dev/null
    stellar keys public-key "$name"
    return
  fi

  if has_soroban_cli; then
    soroban config identity generate "$name" --global >/dev/null 2>&1 || true
    public_key="$(soroban config identity address "$name")"
    fund_public_key "$public_key"
    printf '%s\n' "$public_key"
    return
  fi

  echo "Neither stellar nor soroban CLI is available in contract-runner" >&2
  exit 1
}

deploy_contracts() {
  local entries=()
  local json_key wasm_stem wasm_path contract_id

  for contract in "${contracts[@]}"; do
    json_key="${contract%%:*}"
    wasm_stem="${contract##*:}"
    wasm_path="$CONTRACTS_DIR/target/wasm32-unknown-unknown/release/${wasm_stem}.wasm"

    if [[ ! -f "$wasm_path" ]]; then
      echo "Missing compiled contract wasm: $wasm_path" >&2
      exit 1
    fi

    contract_id="$(deploy_wasm "$wasm_path")"
    entries+=("$(printf '"%s":"%s"' "$json_key" "$contract_id")")
    echo "Deployed $json_key contract: $contract_id"
  done

  write_json_object_file "$CONTRACT_IDS_FILE" "${entries[@]}"
  echo "Wrote contract IDs to $CONTRACT_IDS_FILE"
}

deploy_wasm() {
  local wasm_path="$1"

  if has_stellar_cli; then
    stellar contract deploy \
      --wasm "$wasm_path" \
      --source "$SOURCE_ACCOUNT" \
      --network "$STELLAR_NETWORK"
    return
  fi

  if has_soroban_cli; then
    soroban contract deploy \
      --wasm "$wasm_path" \
      --source "$SOURCE_ACCOUNT" \
      --network "$STELLAR_NETWORK"
    return
  fi

  echo "Neither stellar nor soroban CLI is available in contract-runner" >&2
  exit 1
}

fund_public_key() {
  local public_key="$1"
  local friendbot_url="${FRIENDBOT_URL:-${STELLAR_RPC_URL%/}/friendbot}"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error "${friendbot_url}?addr=${public_key}" >/dev/null
    return
  fi

  echo "curl is required to fund soroban identities through local friendbot" >&2
  exit 1
}

write_json_array_file() {
  local file="$1"
  local key="$2"
  shift 2

  {
    printf '{"%s":[' "$key"
    join_json_entries "$@"
    printf ']}\n'
  } >"$file"
}

write_json_object_file() {
  local file="$1"
  shift

  {
    printf '{'
    join_json_entries "$@"
    printf '}\n'
  } >"$file"
}

join_json_entries() {
  local first=1
  local entry

  for entry in "$@"; do
    if [[ "$first" -eq 0 ]]; then
      printf ','
    fi

    printf '%s' "$entry"
    first=0
  done
}

has_stellar_cli() {
  command -v stellar >/dev/null 2>&1
}

has_soroban_cli() {
  command -v soroban >/dev/null 2>&1
}

main "$@"
