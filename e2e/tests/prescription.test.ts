import assert from "node:assert/strict";
import test from "node:test";

import { readRecords } from "../helpers/api-indexer.ts";
import { loadE2EConfig } from "../helpers/config.ts";
import { waitForJson } from "../helpers/http.ts";
import { loadPrescriptionScenarios } from "../helpers/prescription-scenarios.ts";

const config = loadE2EConfig();

test("prescription bridge writes a dispensation receipt to the patient record", async () => {
  const { happy } = (await loadPrescriptionScenarios()).scenarios;
  const records = await waitForJson(
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
  );

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
