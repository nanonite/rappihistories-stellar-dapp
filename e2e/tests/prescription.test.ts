import assert from "node:assert/strict";
import test from "node:test";

import {
  readInventoryUnitById,
  readPrescriptionById,
  readRecords,
} from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { waitForJson } from "../helpers/http.ts";
import { loadPrescriptionScenarios } from "../helpers/prescription-scenarios.ts";

const config = loadE2EConfig();

test("prescription bridge writes a dispensation receipt to the patient record", async () => {
  const { happy } = (await loadPrescriptionScenarios()).scenarios;
  const [prescription, inventoryUnit, records] = await Promise.all([
    waitForJson(
      "dispensed prescription read model",
      () => readPrescriptionById(config.apiIndexerUrl, happy.prescriptionId),
      (response) =>
        response.prescription.status === "dispensed" &&
        response.prescription.recordId === happy.diagnosisRecordId &&
        response.prescription.patientPseudonym === happy.patientPseudonym &&
        response.prescription.prescriberRef === happy.clinicianPublicKey &&
        response.prescription.pharmacyRef === happy.pharmacyPublicKey &&
        response.prescription.unitId === happy.unitId &&
        response.prescription.reservationRef === happy.reservationRef &&
        response.prescription.receiptRecordId === happy.receiptRecordId,
    ),
    waitForJson(
      "dispensed inventory unit read model",
      () => readInventoryUnitById(config.apiIndexerUrl, happy.unitId),
      (response) =>
        response.inventoryUnit.status === "dispensed" &&
        response.inventoryUnit.prescriptionId === happy.prescriptionId &&
        response.inventoryUnit.batchId === happy.batchId &&
        response.inventoryUnit.reservationRef === happy.reservationRef,
    ),
    waitForJson(
      "dispensation receipt record",
      () => readRecords(config.apiIndexerUrl, happy.patientPseudonym),
      (response) =>
        response.records.some(
          (record) =>
            isRecord(record) &&
            record.recordId === happy.receiptRecordId &&
            record.commitment === happy.receiptCommitment &&
            record.storageRef === happy.receiptLocator,
        ),
    ),
  ]);

  assert.equal(prescription.prescription.commitment, happy.prescriptionCommitment);
  assert.equal(inventoryUnit.inventoryUnit.pharmacyRef, happy.pharmacyPublicKey);
  assert.ok(records.records.length > 0);
});

test("prescription negative paths are rejected during Soroban scenario setup", async () => {
  const { pharmacyOnly, quarantined } = (await loadPrescriptionScenarios()).scenarios;

  assert.equal(pharmacyOnly.denied, true);
  assert.equal(quarantined.denied, true);
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
