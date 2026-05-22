#![cfg(test)]

use super::*;
use soroban_sdk::{Bytes, Env, String};

#[test]
fn test_full_flow() {
    let env = Env::default();
    let contract_id = env.register(MedicalRecordContract, ());

    let patient = Address::generate(&env);
    let doctor = Address::generate(&env);
    let unauthorized = Address::generate(&env);

    MedicalRecordContractClient::init(&env, &contract_id, &patient);

    MedicalRecordContractClient::authorize_doctor(&env, &contract_id, &patient.clone(), &doctor);

    let data_hash = Bytes::from_slice(&env, &[1u8; 32]);
    MedicalRecordContractClient::append_record(
        &env,
        &contract_id,
        &patient,
        &doctor,
        &data_hash,
        &String::from_str(&env, "lab_result"),
        &String::from_str(&env, "Blood work normal"),
    );

    let records = MedicalRecordContractClient::get_records(&env, &contract_id, &patient);
    assert_eq!(records.len(), 1);
    assert_eq!(records.first().unwrap().record_type, String::from_str(&env, "lab_result"));
    assert_eq!(records.first().unwrap().notes, String::from_str(&env, "Blood work normal"));

    let doctors = MedicalRecordContractClient::get_authorized_doctors(&env, &contract_id, &patient);
    assert_eq!(doctors.len(), 1);
    assert_eq!(doctors.first().unwrap(), doctor);

    let is_auth = MedicalRecordContractClient::is_doctor_authorized(&env, &contract_id, &patient, &doctor);
    assert!(is_auth);
}
