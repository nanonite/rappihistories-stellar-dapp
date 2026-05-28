#!/usr/bin/env bash
set -euo pipefail

CONTRACT_IDS_FILE="${CONTRACT_IDS_FILE:-/shared/contract-ids.json}"
SEED_IDENTITIES_FILE="${SEED_IDENTITIES_FILE:-/shared/seed-identities.json}"
KMS_CONFORMANCE_SCENARIOS_FILE="${KMS_CONFORMANCE_SCENARIOS_FILE:-/shared/kms-conformance-scenarios.json}"
STELLAR_RPC_URL="${STELLAR_RPC_URL:-http://stellar-local:8000/soroban/rpc}"
STELLAR_NETWORK_PASSPHRASE="${STELLAR_NETWORK_PASSPHRASE:-Standalone Network ; February 2017}"

main() {
  local access_broker patient_public patient_secret clinician_public clinician_secret responder_public responder_secret

  access_broker="$(read_contract_id accessBroker)"
  patient_public="$(read_identity patient-1 publicKey)"
  patient_secret="$(read_identity patient-1 secretKey)"
  clinician_public="$(read_identity clinician-1 publicKey)"
  clinician_secret="$(read_identity clinician-1 secretKey)"
  responder_public="$(read_identity responder publicKey)"
  responder_secret="$(read_identity responder secretKey)"

  mkdir -p "$(dirname "$KMS_CONFORMANCE_SCENARIOS_FILE")"

  write_scenarios \
    "$access_broker" \
    "$patient_public" \
    "$patient_secret" \
    "$clinician_public" \
    "$clinician_secret" \
    "$responder_public" \
    "$responder_secret"
}

write_scenarios() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local clinician_public="$4"
  local clinician_secret="$5"
  local responder_public="$6"
  local responder_secret="$7"
  local before_reveal revoked_and_vetoed simulated

  before_reveal="$(create_breakglass "$access_broker" "$patient_public" "$patient_secret" "$responder_public" "$responder_secret" before-reveal keep)"
  revoked_and_vetoed="$(create_breakglass "$access_broker" "$patient_public" "$patient_secret" "$responder_public" "$responder_secret" revoked-and-vetoed revoke-and-veto)"
  simulated="$(create_simulated_normal_grant "$access_broker" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret")"

  {
    printf '{"scenarios":{'
    printf '"beforeReveal":%s,' "$before_reveal"
    printf '"revokedAndVetoed":%s,' "$revoked_and_vetoed"
    printf '"simulatedRequestAccess":%s' "$simulated"
    printf '}}\n'
  } >"$KMS_CONFORMANCE_SCENARIOS_FILE"

  echo "Wrote KMS conformance Soroban e2e scenarios to $KMS_CONFORMANCE_SCENARIOS_FILE"
}

create_breakglass() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local responder_public="$4"
  local responder_secret="$5"
  local name="$6"
  local mode="$7"
  local record_id locator locator_hex commitment reveal_at expires_at grant_id invoke_output

  locator="opaque://e2e/kms-conformance/$name/record"
  locator_hex="$(to_hex "$locator")"
  commitment="$(hash_for "$name:commitment")"
  record_id="$(hash_for "$name:record")"
  reveal_at="$(($(date +%s) + 300))"
  expires_at="$((reveal_at + 300))"

  stellar_invoke "$access_broker" "$patient_secret" register_record \
    --owner "$patient_public" \
    --record_id "$record_id" \
    --tier EmergencyBundle \
    --category condition \
    --sensitive false \
    --locator_bytes "$locator_hex" \
    --commitment "$commitment" >/dev/null

  wait_for_record "$access_broker" "$patient_secret" "$record_id"

  invoke_output="$(
    stellar_invoke "$access_broker" "$responder_secret" open_break_glass \
      --responder "$responder_public" \
      --patient "$patient_public" \
      --record_id "$record_id" \
      --purpose emergency \
      --reveal_at "$reveal_at" \
      --expires_at "$expires_at"
  )"
  grant_id="$(printf '%s\n' "$invoke_output" | extract_hex_32)"

  if [[ -z "$grant_id" ]]; then
    printf 'Could not extract KMS conformance break-glass grant id for %s\n%s\n' "$name" "$invoke_output" >&2
    return 1
  fi

  if [[ "$mode" == "revoke-and-veto" ]]; then
    stellar_invoke "$access_broker" "$patient_secret" veto \
      --patient "$patient_public" \
      --grant_id "$grant_id" >/dev/null
    stellar_invoke "$access_broker" "$patient_secret" revoke \
      --owner "$patient_public" \
      --grant_id "$grant_id" >/dev/null
  fi

  printf '{"patientPseudonym":"%s","requesterPublicKey":"%s","requesterSecretKey":"%s","grantId":"%s","locator":"%s"}' \
    "$patient_public" "$responder_public" "$responder_secret" "$grant_id" "$locator"
}

create_simulated_normal_grant() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local clinician_public="$4"
  local clinician_secret="$5"
  local record_id locator locator_hex commitment expires_at grant_id invoke_output

  locator="opaque://e2e/kms-conformance/simulated/record"
  locator_hex="$(to_hex "$locator")"
  commitment="$(hash_for simulated:commitment)"
  record_id="$(hash_for simulated:record)"
  expires_at="$(($(date +%s) + 300))"

  stellar_invoke "$access_broker" "$patient_secret" register_record \
    --owner "$patient_public" \
    --record_id "$record_id" \
    --tier FullHistory \
    --category condition \
    --sensitive false \
    --locator_bytes "$locator_hex" \
    --commitment "$commitment" >/dev/null

  wait_for_record "$access_broker" "$patient_secret" "$record_id"

  invoke_output="$(
    stellar_invoke_no_send "$access_broker" "$patient_secret" create_normal_grant \
      --patient "$patient_public" \
      --grantee "$clinician_public" \
      --record_id "$record_id" \
      --purpose treatment \
      --scope_category condition \
      --expires_at "$expires_at"
  )"
  grant_id="$(printf '%s\n' "$invoke_output" | extract_hex_32)"

  if [[ -z "$grant_id" ]]; then
    printf 'Could not extract simulated grant id from output:\n%s\n' "$invoke_output" >&2
    return 1
  fi

  printf '{"patientPseudonym":"%s","requesterPublicKey":"%s","requesterSecretKey":"%s","grantId":"%s","locator":"%s"}' \
    "$patient_public" "$clinician_public" "$clinician_secret" "$grant_id" "$locator"
}

wait_for_record() {
  local access_broker="$1"
  local patient_secret="$2"
  local record_id="$3"
  local attempt

  for attempt in $(seq 1 20); do
    if stellar_invoke "$access_broker" "$patient_secret" get_record \
      --record_id "$record_id" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  printf 'Timed out waiting for KMS conformance record %s\n' "$record_id" >&2
  return 1
}

stellar_invoke() {
  local contract_id="$1"
  local source_account="$2"
  shift 2

  stellar contract invoke \
    --id "$contract_id" \
    --source-account "$source_account" \
    --rpc-url "$STELLAR_RPC_URL" \
    --network-passphrase "$STELLAR_NETWORK_PASSPHRASE" \
    --auto-sign \
    -- "$@"
}

stellar_invoke_no_send() {
  local contract_id="$1"
  local source_account="$2"
  shift 2

  stellar contract invoke \
    --id "$contract_id" \
    --source-account "$source_account" \
    --rpc-url "$STELLAR_RPC_URL" \
    --network-passphrase "$STELLAR_NETWORK_PASSPHRASE" \
    --send no \
    --auto-sign \
    -- "$@"
}

read_contract_id() {
  local key="$1"
  sed -E "s/.*\"$key\":\"([^\"]+)\".*/\1/" "$CONTRACT_IDS_FILE"
}

read_identity() {
  local alias="$1"
  local field="$2"
  grep -o "{\"alias\":\"$alias\"[^}]*}" "$SEED_IDENTITIES_FILE" \
    | sed -E "s/.*\"$field\":\"([^\"]+)\".*/\1/"
}

hash_for() {
  sha256_hex "medichain:e2e:kms-conformance:$1"
}

sha256_hex() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

to_hex() {
  printf '%s' "$1" | od -An -tx1 -v | tr -d ' \n'
}

extract_hex_32() {
  grep -Eo '[[:xdigit:]]{64}' | tail -1 | tr '[:upper:]' '[:lower:]'
}

main "$@"
