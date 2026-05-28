import { readFile } from "node:fs/promises";

export interface PrescriptionHappyScenario {
  readonly patientPseudonym: string;
  readonly clinicianPublicKey: string;
  readonly pharmacyPublicKey: string;
  readonly prescriptionId: string;
  readonly diagnosisRecordId: string;
  readonly prescriptionCommitment: string;
  readonly unitId: string;
  readonly batchId: string;
  readonly reservationRef: string;
  readonly medicineIntent: string;
  readonly receiptRecordId: string;
  readonly receiptLocator: string;
  readonly receiptCommitment: string;
}

export interface PrescriptionDeniedScenario {
  readonly prescriptionId: string;
  readonly unitId: string;
  readonly denied: true;
}

export interface PrescriptionScenarioFile {
  readonly scenarios: {
    readonly happy: PrescriptionHappyScenario;
    readonly pharmacyOnly: PrescriptionDeniedScenario;
    readonly quarantined: PrescriptionDeniedScenario;
  };
}

export async function loadPrescriptionScenarios(
  path = process.env.PRESCRIPTION_SCENARIOS_FILE ??
    "/shared/prescription-scenarios.json",
): Promise<PrescriptionScenarioFile> {
  const parsed = JSON.parse(await readFile(path, "utf8")) as unknown;

  if (!isRecord(parsed) || !isRecord(parsed.scenarios)) {
    throw new Error(`${path} must contain scenarios`);
  }

  return {
    scenarios: {
      happy: readHappy(parsed.scenarios.happy, "happy"),
      pharmacyOnly: readDenied(parsed.scenarios.pharmacyOnly, "pharmacyOnly"),
      quarantined: readDenied(parsed.scenarios.quarantined, "quarantined"),
    },
  };
}

function readHappy(value: unknown, name: string): PrescriptionHappyScenario {
  const scenario = requireRecord(value, `scenarios.${name}`);

  return {
    patientPseudonym: requireString(scenario.patientPseudonym, name),
    clinicianPublicKey: requireString(scenario.clinicianPublicKey, name),
    pharmacyPublicKey: requireString(scenario.pharmacyPublicKey, name),
    prescriptionId: requireHex(scenario.prescriptionId, name),
    diagnosisRecordId: requireHex(scenario.diagnosisRecordId, name),
    prescriptionCommitment: requireHex(scenario.prescriptionCommitment, name),
    unitId: requireHex(scenario.unitId, name),
    batchId: requireHex(scenario.batchId, name),
    reservationRef: requireHex(scenario.reservationRef, name),
    medicineIntent: requireString(scenario.medicineIntent, name),
    receiptRecordId: requireHex(scenario.receiptRecordId, name),
    receiptLocator: requireString(scenario.receiptLocator, name),
    receiptCommitment: requireHex(scenario.receiptCommitment, name),
  };
}

function readDenied(value: unknown, name: string): PrescriptionDeniedScenario {
  const scenario = requireRecord(value, `scenarios.${name}`);

  if (scenario.denied !== true) {
    throw new Error(`${name} must record denied=true`);
  }

  return {
    prescriptionId: requireHex(scenario.prescriptionId, name),
    unitId: requireHex(scenario.unitId, name),
    denied: true,
  };
}

function requireRecord(
  value: unknown,
  location: string,
): Record<string, unknown> {
  if (!isRecord(value)) {
    throw new Error(`${location} must be an object`);
  }

  return value;
}

function requireString(value: unknown, location: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${location} has an invalid string field`);
  }

  return value;
}

function requireHex(value: unknown, location: string): string {
  const text = requireString(value, location);

  if (!/^[0-9a-f]{64}$/i.test(text)) {
    throw new Error(`${location} has an invalid 32-byte hex field`);
  }

  return text.toLowerCase();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
