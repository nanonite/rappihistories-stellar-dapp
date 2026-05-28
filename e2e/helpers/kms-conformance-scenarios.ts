import { readFile } from "node:fs/promises";

export interface KmsConformanceScenario {
  readonly patientPseudonym: string;
  readonly requesterPublicKey: string;
  readonly requesterSecretKey: string;
  readonly grantId: string;
  readonly locator: string;
}

export interface KmsConformanceScenarioFile {
  readonly scenarios: {
    readonly beforeReveal: KmsConformanceScenario;
    readonly revokedAndVetoed: KmsConformanceScenario;
    readonly simulatedRequestAccess: KmsConformanceScenario;
  };
}

export async function loadKmsConformanceScenarios(
  path = process.env.KMS_CONFORMANCE_SCENARIOS_FILE ??
    "/shared/kms-conformance-scenarios.json",
): Promise<KmsConformanceScenarioFile> {
  const parsed = JSON.parse(await readFile(path, "utf8")) as unknown;

  if (!isRecord(parsed) || !isRecord(parsed.scenarios)) {
    throw new Error(`${path} must contain scenarios`);
  }

  return {
    scenarios: {
      beforeReveal: readScenario(parsed.scenarios.beforeReveal, "beforeReveal"),
      revokedAndVetoed: readScenario(
        parsed.scenarios.revokedAndVetoed,
        "revokedAndVetoed",
      ),
      simulatedRequestAccess: readScenario(
        parsed.scenarios.simulatedRequestAccess,
        "simulatedRequestAccess",
      ),
    },
  };
}

function readScenario(value: unknown, name: string): KmsConformanceScenario {
  const scenario = requireRecord(value, `scenarios.${name}`);

  return {
    patientPseudonym: requireString(scenario.patientPseudonym, name),
    requesterPublicKey: requireString(scenario.requesterPublicKey, name),
    requesterSecretKey: requireString(scenario.requesterSecretKey, name),
    grantId: requireHex(scenario.grantId, name),
    locator: requireString(scenario.locator, name),
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
