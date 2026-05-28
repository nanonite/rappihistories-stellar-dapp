#!/usr/bin/env bash
set -euo pipefail

CONTRACT_IDS_FILE="${CONTRACT_IDS_FILE:-/shared/contract-ids.json}"
SEED_IDENTITIES_FILE="${SEED_IDENTITIES_FILE:-/shared/seed-identities.json}"
BREAKGLASS_SCENARIOS_FILE="${BREAKGLASS_SCENARIOS_FILE:-/shared/breakglass-scenarios.json}"
STELLAR_RPC_URL="${STELLAR_RPC_URL:-http://stellar-local:8000/soroban/rpc}"
STELLAR_NETWORK_PASSPHRASE="${STELLAR_NETWORK_PASSPHRASE:-Standalone Network ; February 2017}"

main() {
  local access_broker patient_public patient_secret responder_public responder_secret cosigner_public cosigner_secret cosigner_signer

  access_broker="$(read_contract_id accessBroker)"
  patient_public="$(read_identity patient-1 publicKey)"
  patient_secret="$(read_identity patient-1 secretKey)"
  responder_public="$(read_identity responder publicKey)"
  responder_secret="$(read_identity responder secretKey)"
  cosigner_public="$(read_identity clinician-1 publicKey)"
  cosigner_secret="$(read_identity clinician-1 secretKey)"
  cosigner_signer="medichain-e2e-tokenless-cosigner"
  ensure_identity_alias "$cosigner_signer" "$cosigner_secret"

  mkdir -p "$(dirname "$BREAKGLASS_SCENARIOS_FILE")"

  write_scenarios \
    "$access_broker" \
    "$patient_public" \
    "$patient_secret" \
    "$responder_public" \
    "$responder_secret" \
    "$cosigner_public" \
    "$cosigner_signer"
}

write_scenarios() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local responder_public="$4"
  local responder_secret="$5"
  local cosigner_public="$6"
  local cosigner_signer="$7"
  local now vetoed no_veto tokenless

  now="$(date +%s)"
  vetoed="$(create_breakglass_scenario "$access_broker" "$patient_public" "$patient_secret" "$responder_public" "$responder_secret" vetoed "$((now + 300))" "$((now + 600))" yes)"
  no_veto="$(create_breakglass_scenario "$access_broker" "$patient_public" "$patient_secret" "$responder_public" "$responder_secret" no-veto delay:8 "$((now + 600))" no)"
  tokenless="$(create_tokenless_scenario "$access_broker" "$patient_public" "$responder_public" "$responder_secret" "$cosigner_public" "$cosigner_signer" tokenless "$((now + 600))")"

  sleep 9

  {
    printf '{"scenarios":{'
    printf '"vetoed":%s,' "$vetoed"
    printf '"noVeto":%s,' "$no_veto"
    printf '"tokenless":%s' "$tokenless"
    printf '}}\n'
  } >"$BREAKGLASS_SCENARIOS_FILE"

  echo "Wrote break-glass Soroban e2e scenarios to $BREAKGLASS_SCENARIOS_FILE"
}

create_breakglass_scenario() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local responder_public="$4"
  local responder_secret="$5"
  local name="$6"
  local reveal_at="$7"
  local expires_at="$8"
  local should_veto="$9"
  local record_id locator commitment grant_id invoke_output

  create_emergency_record "$access_broker" "$patient_public" "$patient_secret" "$name" || return 1
  record_id="$CREATED_RECORD_ID"
  locator="$CREATED_LOCATOR"
  commitment="$CREATED_COMMITMENT"

  if [[ "$reveal_at" == delay:* ]]; then
    reveal_at="$(($(date +%s) + ${reveal_at#delay:}))"
  fi

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
    printf 'Could not extract break-glass grant id for %s from output:\n%s\n' "$name" "$invoke_output" >&2
    return 1
  fi

  if [[ "$should_veto" == "yes" ]]; then
    stellar_invoke "$access_broker" "$patient_secret" veto \
      --patient "$patient_public" \
      --grant_id "$grant_id" >/dev/null
  fi

  scenario_json "$patient_public" "$responder_public" "$responder_secret" "$record_id" "$grant_id" "$locator" "$commitment" "$reveal_at" "$expires_at"
}

create_tokenless_scenario() {
  local access_broker="$1"
  local patient_public="$2"
  local responder_public="$3"
  local responder_secret="$4"
  local cosigner_public="$5"
  local cosigner_signer="$6"
  local name="$7"
  local expires_at="$8"
  local record_id locator commitment grant_id invoke_output

  create_emergency_record "$access_broker" "$patient_public" "$(read_identity patient-1 secretKey)" "$name" || return 1
  record_id="$CREATED_RECORD_ID"
  locator="$CREATED_LOCATOR"
  commitment="$CREATED_COMMITMENT"

  invoke_output="$(
    stellar_invoke "$access_broker" "$cosigner_signer" create_tokenless_fallback_grant \
      --requester "$responder_public" \
      --cosigner "$cosigner_public" \
      --patient "$patient_public" \
      --record_id "$record_id" \
      --purpose emergency \
      --expires_at "$expires_at"
  )"
  grant_id="$(printf '%s\n' "$invoke_output" | extract_hex_32)"

  if [[ -z "$grant_id" ]]; then
    printf 'Could not extract tokenless fallback grant id for %s from output:\n%s\n' "$name" "$invoke_output" >&2
    return 1
  fi

  scenario_json "$patient_public" "$responder_public" "$responder_secret" "$record_id" "$grant_id" "$locator" "$commitment" 0 "$expires_at"
}

ensure_identity_alias() {
  local alias="$1"
  local secret="$2"

  printf '%s\n' "$secret" | stellar keys add "$alias" --secret-key --overwrite >/dev/null
}

create_emergency_record() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local name="$4"
  local plaintext locator_hex

  plaintext="{\"subject\":\"e2e-breakglass-record\",\"scenario\":\"$name\",\"patient\":\"$patient_public\"}"
  CREATED_LOCATOR="opaque://e2e/breakglass/$name/$(date +%s%N)"
  locator_hex="$(to_hex "$CREATED_LOCATOR")"
  CREATED_COMMITMENT="$(sha256_hex "$plaintext")"
  CREATED_RECORD_ID="$(sha256_hex "$name:$CREATED_LOCATOR")"

  for attempt in $(seq 1 3); do
    stellar_invoke "$access_broker" "$patient_secret" register_record \
      --owner "$patient_public" \
      --record_id "$CREATED_RECORD_ID" \
      --tier EmergencyBundle \
      --category condition \
      --sensitive false \
      --locator_bytes "$locator_hex" \
      --commitment "$CREATED_COMMITMENT" >/dev/null 2>&1 || true

    if wait_for_record "$access_broker" "$patient_secret" "$CREATED_RECORD_ID"; then
      return 0
    fi

    printf 'Retrying emergency record %s registration after attempt %s\n' "$CREATED_RECORD_ID" "$attempt" >&2
  done

  printf 'Timed out registering emergency record %s\n' "$CREATED_RECORD_ID" >&2
  return 1
}

wait_for_record() {
  local access_broker="$1"
  local patient_secret="$2"
  local record_id="$3"
  local attempt

  for attempt in $(seq 1 10); do
    if stellar_invoke "$access_broker" "$patient_secret" get_record \
      --record_id "$record_id" >/dev/null 2>&1; then
      return 0
    fi

    sleep 2
  done

  printf 'Timed out waiting for emergency record %s to become readable\n' "$record_id" >&2
  return 1
}

scenario_json() {
  local patient_public="$1"
  local requester_public="$2"
  local requester_secret="$3"
  local record_id="$4"
  local grant_id="$5"
  local locator="$6"
  local commitment="$7"
  local reveal_at="$8"
  local expires_at="$9"

  printf '{"patientPseudonym":"%s","requesterPublicKey":"%s","requesterSecretKey":"%s","recordId":"%s","grantId":"%s","locator":"%s","commitment":"%s","plaintextSha256":"%s","revealAt":%s,"expiresAt":%s}' \
    "$patient_public" \
    "$requester_public" \
    "$requester_secret" \
    "$record_id" \
    "$grant_id" \
    "$locator" \
    "$commitment" \
    "$commitment" \
    "$reveal_at" \
    "$expires_at"
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
