#!/usr/bin/env bash
set -euo pipefail

CONTRACT_IDS_FILE="${CONTRACT_IDS_FILE:-/shared/contract-ids.json}"
SEED_IDENTITIES_FILE="${SEED_IDENTITIES_FILE:-/shared/seed-identities.json}"
TIER3_SCENARIOS_FILE="${TIER3_SCENARIOS_FILE:-/shared/tier3-scenarios.json}"
STELLAR_RPC_URL="${STELLAR_RPC_URL:-http://stellar-local:8000/soroban/rpc}"
STELLAR_NETWORK_PASSPHRASE="${STELLAR_NETWORK_PASSPHRASE:-Standalone Network ; February 2017}"

main() {
  local access_broker patient_public patient_secret clinician_public clinician_secret

  access_broker="$(read_contract_id accessBroker)"
  patient_public="$(read_identity patient-1 publicKey)"
  patient_secret="$(read_identity patient-1 secretKey)"
  clinician_public="$(read_identity clinician-1 publicKey)"
  clinician_secret="$(read_identity clinician-1 secretKey)"

  mkdir -p "$(dirname "$TIER3_SCENARIOS_FILE")"

  write_scenarios \
    "$access_broker" \
    "$patient_public" \
    "$patient_secret" \
    "$clinician_public" \
    "$clinician_secret"
}

write_scenarios() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local clinician_public="$4"
  local clinician_secret="$5"
  local now happy revoked expired

  now="$(date +%s)"
  happy="$(create_scenario "$access_broker" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret" happy "$((now + 300))" no)"
  revoked="$(create_scenario "$access_broker" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret" revoked "$((now + 300))" yes)"
  expired="$(create_scenario "$access_broker" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret" expired "$((now + 12))" no)"

  sleep 13

  {
    printf '{"scenarios":{'
    printf '"happy":%s,' "$happy"
    printf '"revoked":%s,' "$revoked"
    printf '"expired":%s' "$expired"
    printf '}}\n'
  } >"$TIER3_SCENARIOS_FILE"

  echo "Wrote Tier 3 Soroban e2e scenarios to $TIER3_SCENARIOS_FILE"
}

create_scenario() {
  local access_broker="$1"
  local patient_public="$2"
  local patient_secret="$3"
  local clinician_public="$4"
  local clinician_secret="$5"
  local name="$6"
  local expires_at="$7"
  local should_revoke="$8"
  local plaintext locator locator_hex commitment record_id grant_id invoke_output

  plaintext="{\"subject\":\"e2e-tier3-record\",\"scenario\":\"$name\",\"patient\":\"$patient_public\"}"
  locator="opaque://e2e/$name/$(date +%s%N)"
  locator_hex="$(to_hex "$locator")"
  commitment="$(sha256_hex "$plaintext")"
  record_id="$(sha256_hex "$name:$locator")"

  stellar_invoke "$access_broker" "$patient_secret" register_record \
    --owner "$patient_public" \
    --record_id "$record_id" \
    --tier FullHistory \
    --category condition \
    --sensitive false \
    --locator_bytes "$locator_hex" \
    --commitment "$commitment" >/dev/null

  invoke_output="$(
    stellar_invoke "$access_broker" "$patient_secret" create_normal_grant \
      --patient "$patient_public" \
      --grantee "$clinician_public" \
      --record_id "$record_id" \
      --purpose treatment \
      --scope_category condition \
      --expires_at "$expires_at"
  )"
  grant_id="$(printf '%s\n' "$invoke_output" | extract_hex_32)"

  if [[ -z "$grant_id" ]]; then
    printf 'Could not extract grant id for %s from create_normal_grant output:\n%s\n' "$name" "$invoke_output" >&2
    return 1
  fi

  if [[ "$should_revoke" == "yes" ]]; then
    stellar_invoke "$access_broker" "$patient_secret" revoke \
      --owner "$patient_public" \
      --grant_id "$grant_id" >/dev/null
  fi

  printf '{"patientPseudonym":"%s","clinicianPublicKey":"%s","clinicianSecretKey":"%s","recordId":"%s","grantId":"%s","locator":"%s","commitment":"%s","plaintextSha256":"%s","expiresAt":%s}' \
    "$patient_public" \
    "$clinician_public" \
    "$clinician_secret" \
    "$record_id" \
    "$grant_id" \
    "$locator" \
    "$commitment" \
    "$commitment" \
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
