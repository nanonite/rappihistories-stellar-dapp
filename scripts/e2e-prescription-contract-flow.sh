#!/usr/bin/env bash
set -euo pipefail

CONTRACT_IDS_FILE="${CONTRACT_IDS_FILE:-/shared/contract-ids.json}"
SEED_IDENTITIES_FILE="${SEED_IDENTITIES_FILE:-/shared/seed-identities.json}"
PRESCRIPTION_SCENARIOS_FILE="${PRESCRIPTION_SCENARIOS_FILE:-/shared/prescription-scenarios.json}"
STELLAR_RPC_URL="${STELLAR_RPC_URL:-http://stellar-local:8000/soroban/rpc}"
STELLAR_NETWORK_PASSPHRASE="${STELLAR_NETWORK_PASSPHRASE:-Standalone Network ; February 2017}"

main() {
  local access_broker prescription supplychain identity admin_public admin_secret
  local patient_public patient_secret clinician_public clinician_secret pharmacy_public pharmacy_secret pharmacy_signer

  access_broker="$(read_contract_id accessBroker)"
  prescription="$(read_contract_id prescription)"
  supplychain="$(read_contract_id supplychain)"
  identity="$(read_contract_id identity)"
  admin_public="$(read_identity admin publicKey)"
  admin_secret="$(read_identity admin secretKey)"
  patient_public="$(read_identity patient-1 publicKey)"
  patient_secret="$(read_identity patient-1 secretKey)"
  clinician_public="$(read_identity clinician-1 publicKey)"
  clinician_secret="$(read_identity clinician-1 secretKey)"
  pharmacy_public="$(read_identity pharmacy publicKey)"
  pharmacy_secret="$(read_identity pharmacy secretKey)"
  pharmacy_signer="medichain-e2e-pharmacy"

  ensure_identity_alias "$pharmacy_signer" "$pharmacy_secret"
  mkdir -p "$(dirname "$PRESCRIPTION_SCENARIOS_FILE")"

  configure_contracts \
    "$prescription" \
    "$supplychain" \
    "$identity" \
    "$access_broker" \
    "$admin_public" \
    "$admin_secret" \
    "$pharmacy_public"

  write_scenarios \
    "$access_broker" \
    "$prescription" \
    "$supplychain" \
    "$patient_public" \
    "$patient_secret" \
    "$clinician_public" \
    "$clinician_secret" \
    "$pharmacy_public" \
    "$pharmacy_secret" \
    "$pharmacy_signer"
}

configure_contracts() {
  local prescription="$1"
  local supplychain="$2"
  local identity="$3"
  local access_broker="$4"
  local admin_public="$5"
  local admin_secret="$6"
  local pharmacy_public="$7"

  stellar_invoke "$prescription" "$admin_secret" initialize \
    --admin "$admin_public" >/dev/null
  stellar_invoke "$supplychain" "$admin_secret" initialize \
    --admin "$admin_public" >/dev/null
  stellar_invoke "$prescription" "$admin_secret" configure_dependencies \
    --admin "$admin_public" \
    --identity_contract_id "$identity" \
    --access_broker_contract_id "$access_broker" \
    --supplychain_contract_id "$supplychain" >/dev/null
  stellar_invoke "$supplychain" "$admin_secret" register_oracle \
    --admin "$admin_public" \
    --oracle "$pharmacy_public" >/dev/null
  stellar_invoke "$supplychain" "$admin_secret" configure_prescription_contract \
    --admin "$admin_public" \
    --prescription_contract "$prescription" >/dev/null
}

write_scenarios() {
  local access_broker="$1"
  local prescription="$2"
  local supplychain="$3"
  local patient_public="$4"
  local patient_secret="$5"
  local clinician_public="$6"
  local clinician_secret="$7"
  local pharmacy_public="$8"
  local pharmacy_secret="$9"
  local pharmacy_signer="${10}"
  local happy pharmacy_only quarantine

  happy="$(create_happy_path "$access_broker" "$prescription" "$supplychain" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret" "$pharmacy_public" "$pharmacy_signer")"
  pharmacy_only="$(assert_pharmacy_only_fails "$prescription" "$supplychain" "$patient_public" "$clinician_public" "$clinician_secret" "$pharmacy_public" "$pharmacy_secret")"
  quarantine="$(assert_quarantined_reservation_fails "$prescription" "$supplychain" "$patient_public" "$patient_secret" "$clinician_public" "$clinician_secret" "$pharmacy_public" "$pharmacy_secret")"

  {
    printf '{"scenarios":{'
    printf '"happy":%s,' "$happy"
    printf '"pharmacyOnly":%s,' "$pharmacy_only"
    printf '"quarantined":%s' "$quarantine"
    printf '}}\n'
  } >"$PRESCRIPTION_SCENARIOS_FILE"

  echo "Wrote prescription Soroban e2e scenarios to $PRESCRIPTION_SCENARIOS_FILE"
}

create_happy_path() {
  local access_broker="$1"
  local prescription="$2"
  local supplychain="$3"
  local patient_public="$4"
  local patient_secret="$5"
  local clinician_public="$6"
  local clinician_secret="$7"
  local pharmacy_public="$8"
  local pharmacy_signer="$9"
  local prescription_id diagnosis_record_id prescription_commitment unit_id batch_id reservation_ref
  local receipt_record_id receipt_locator receipt_locator_hex receipt_commitment plaintext

  prescription_id="$(hash_for happy:prescription)"
  diagnosis_record_id="$(hash_for happy:diagnosis)"
  prescription_commitment="$(hash_for happy:prescription-commitment)"
  unit_id="$(hash_for happy:unit)"
  batch_id="$(hash_for happy:batch)"
  reservation_ref="$(hash_for happy:reservation)"
  receipt_record_id="$(hash_for happy:receipt-record)"
  receipt_locator="opaque://e2e/prescription/happy/receipt"
  receipt_locator_hex="$(to_hex "$receipt_locator")"
  plaintext="{\"subject\":\"e2e-dispensation-receipt\",\"prescription\":\"$prescription_id\",\"patient\":\"$patient_public\"}"
  receipt_commitment="$(sha256_hex "$plaintext")"

  stellar_invoke "$supplychain" "$pharmacy_signer" register_unit \
    --oracle "$pharmacy_public" \
    --unit_id "$unit_id" \
    --batch_id "$batch_id" >/dev/null
  stellar_invoke "$prescription" "$clinician_secret" issue \
    --clinician "$clinician_public" \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --diagnosis_record_id "$diagnosis_record_id" \
    --prescription_commitment "$prescription_commitment" >/dev/null
  stellar_invoke "$prescription" "$patient_secret" select_pharmacy \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --pharmacy "$pharmacy_public" \
    --unit_id "$unit_id" \
    --reservation_ref "$reservation_ref" >/dev/null
  stellar_invoke "$prescription" "$patient_secret" dispense \
    --pharmacy "$pharmacy_public" \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --receipt_record_id "$receipt_record_id" \
    --receipt_locator_bytes "$receipt_locator_hex" \
    --receipt_commitment "$receipt_commitment" >/dev/null

  wait_for_record "$access_broker" "$patient_secret" "$receipt_record_id"

  printf '{"patientPseudonym":"%s","prescriptionId":"%s","unitId":"%s","receiptRecordId":"%s","receiptLocator":"%s","receiptCommitment":"%s"}' \
    "$patient_public" \
    "$prescription_id" \
    "$unit_id" \
    "$receipt_record_id" \
    "$receipt_locator" \
    "$receipt_commitment"
}

assert_pharmacy_only_fails() {
  local prescription="$1"
  local supplychain="$2"
  local patient_public="$3"
  local clinician_public="$4"
  local clinician_secret="$5"
  local pharmacy_public="$6"
  local pharmacy_secret="$7"
  local prescription_id diagnosis_record_id prescription_commitment unit_id batch_id reservation_ref receipt_record_id receipt_commitment

  prescription_id="$(hash_for pharmacy-only:prescription)"
  diagnosis_record_id="$(hash_for pharmacy-only:diagnosis)"
  prescription_commitment="$(hash_for pharmacy-only:prescription-commitment)"
  unit_id="$(hash_for pharmacy-only:unit)"
  batch_id="$(hash_for pharmacy-only:batch)"
  reservation_ref="$(hash_for pharmacy-only:reservation)"
  receipt_record_id="$(hash_for pharmacy-only:receipt-record)"
  receipt_commitment="$(hash_for pharmacy-only:receipt)"

  stellar_invoke "$supplychain" "$pharmacy_secret" register_unit \
    --oracle "$pharmacy_public" \
    --unit_id "$unit_id" \
    --batch_id "$batch_id" >/dev/null
  stellar_invoke "$prescription" "$clinician_secret" issue \
    --clinician "$clinician_public" \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --diagnosis_record_id "$diagnosis_record_id" \
    --prescription_commitment "$prescription_commitment" >/dev/null

  if stellar_invoke "$prescription" "$pharmacy_secret" dispense \
    --pharmacy "$pharmacy_public" \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --receipt_record_id "$receipt_record_id" \
    --receipt_locator_bytes "$(to_hex opaque://e2e/prescription/pharmacy-only/receipt)" \
    --receipt_commitment "$receipt_commitment" >/dev/null 2>&1; then
    echo "pharmacy-only dispense unexpectedly succeeded" >&2
    return 1
  fi

  printf '{"prescriptionId":"%s","unitId":"%s","denied":true}' "$prescription_id" "$unit_id"
}

assert_quarantined_reservation_fails() {
  local prescription="$1"
  local supplychain="$2"
  local patient_public="$3"
  local patient_secret="$4"
  local clinician_public="$5"
  local clinician_secret="$6"
  local pharmacy_public="$7"
  local pharmacy_secret="$8"
  local prescription_id diagnosis_record_id prescription_commitment unit_id batch_id reservation_ref

  prescription_id="$(hash_for quarantined:prescription)"
  diagnosis_record_id="$(hash_for quarantined:diagnosis)"
  prescription_commitment="$(hash_for quarantined:prescription-commitment)"
  unit_id="$(hash_for quarantined:unit)"
  batch_id="$(hash_for quarantined:batch)"
  reservation_ref="$(hash_for quarantined:reservation)"

  stellar_invoke "$supplychain" "$pharmacy_secret" register_unit \
    --oracle "$pharmacy_public" \
    --unit_id "$unit_id" \
    --batch_id "$batch_id" >/dev/null
  stellar_invoke "$supplychain" "$pharmacy_secret" quarantine_batch \
    --oracle "$pharmacy_public" \
    --batch_id "$batch_id" >/dev/null
  stellar_invoke "$prescription" "$clinician_secret" issue \
    --clinician "$clinician_public" \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --diagnosis_record_id "$diagnosis_record_id" \
    --prescription_commitment "$prescription_commitment" >/dev/null

  if stellar_invoke "$prescription" "$patient_secret" select_pharmacy \
    --patient "$patient_public" \
    --prescription_id "$prescription_id" \
    --pharmacy "$pharmacy_public" \
    --unit_id "$unit_id" \
    --reservation_ref "$reservation_ref" >/dev/null 2>&1; then
    echo "quarantined batch reservation unexpectedly succeeded" >&2
    return 1
  fi

  printf '{"prescriptionId":"%s","unitId":"%s","denied":true}' "$prescription_id" "$unit_id"
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

  printf 'Timed out waiting for dispensation receipt record %s\n' "$record_id" >&2
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

ensure_identity_alias() {
  local alias="$1"
  local secret="$2"

  printf '%s\n' "$secret" | stellar keys add "$alias" --secret-key --overwrite >/dev/null
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
  sha256_hex "medichain:e2e:prescription:$1"
}

sha256_hex() {
  printf '%s' "$1" | sha256sum | awk '{print $1}'
}

to_hex() {
  printf '%s' "$1" | od -An -tx1 -v | tr -d ' \n'
}

main "$@"
